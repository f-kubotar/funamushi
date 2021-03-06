vec2 = (x, y) -> new Two.Vector(x, y)

class Rect
  constructor: (@x, @y, @w, @h) ->

  intersection: (pos) ->
    @x <= pos.x and
    @y <= pos.y and
    @x + @w >= pos.x and
    @y + @h >= pos.y

  tl: -> { x: @x,      y: @y }
  tr: -> { x: @x + @w, y: @y }
  bl: -> { x: @x,      y: @y + @h }
  br: -> { x: @x + @w, y: @y + @h }
  center: ->
    x: @x + @w / 2
    y: @y + @h / 2

  corners: ->
    tl: @tl()
    tr: @tr()
    bl: @bl()
    br: @br()

  cornersArray: -> [@tl(), @tr(), @bl(), @br()]

class Book extends Backbone.Model
  defaults:
    x: 0
    y: 0

  rect: -> new Rect(@get('x'), @get('y'), @get('w'), @get('h'))

class Books extends Backbone.Collection
  model: Book

class Circle extends Backbone.Model
  defaults: -> 
    x: 0
    y: 0
    r: 0
    books: new Books

  collision: (book) ->
    r = @get('r')
    radius2 = r * r
    v = vec2(@get('x'), @get('y'))

    rect = book.rect()

    # TODO: 頂点しか比較してないので未完成
    if (v.distanceToSquared(rect.tl()) <= radius2) or
       (v.distanceToSquared(rect.tr()) <= radius2) or
       (v.distanceToSquared(rect.bl()) <= radius2) or
       (v.distanceToSquared(rect.br()) <= radius2)   
      @trigger 'collide', book

class Circles extends Backbone.Collection
  model: Circle

class BookView extends Backbone.View
  tagName: 'img'
  className: 'book'

  attributes: ->
    style: 'display: inline-block; position: absolute; z-index: 1000;'
    src: @model.get('image_url')
    alt: @model.get('title')

  events:
    'load': ->
      if !@model.get('w')? or !@model.get('h')?
        @model.set w: @$el.width(), h: @$el.height()

    'drag': (e) ->
      pos = @$el.position()
      @model.set(x: pos.left, y: pos.top)

  initialize: ->
    @$el.draggable()

class BooksView extends Backbone.View
  render: ->
    $el = @$el
    @collection.each (book) ->
      bookView = new BookView(model: book)
      $el.append bookView.render().el
    this

class CircleView extends Backbone.View
  initialize: (options) ->
    @canCollide = true
    @two = options.two

    @shape = @two.makeCircle(@model.get('x'), @model.get('y'), @model.get('r'))
    @shape.linewidth = 1
    # @shape.noStroke()
    @shape.noFill()

    _.each @shape.vertices, (v) ->
      v.was = v.clone()

    @listenTo @model, 'collide', _.bind(@collision, this)

  updateColor: ->
    colors = [
      #F4D6E0'
      '#DE7699'
      '#CCE9F9'
      '#4CBAEB'
      '#D6E9C9'
      '#72C575'
      '#F9F4D6'
      '#F7D663'
    ]
    @shape.stroke = colors[_.random(colors.length - 1)]

  # FIXME: 孫要素の場合を考慮してない
  localPositionAt: (worldPos) ->
    t = @shape.translation
    vec2(worldPos.x - t.x, worldPos.y - t.y)

  intersection: (worldPos) ->
    radius = @model.get('r')
    @shape.translation.distanceToSquared(worldPos) <= radius * radius

  # TODO: かなり手抜き
  collision: (book) ->
    return unless @canCollide

    rect = book.rect()
    corners = rect.cornersArray()

    t = @shape.translation
    vertices = @shape.vertices
    radius   = @model.get('r')
    radius2  = radius * radius
    
    holdDistanceToSquared = radius2 * 0.3

    # 内側
    # isInner = _.all(corners, (c) -> (t.distanceToSquared(c)) <= radius2)
    isInner = @intersection(rect.center())
    corner =
      if isInner
        _.max(corners, (c) -> t.distanceToSquared(c))
      else
        _.min(corners, (c) -> t.distanceToSquared(c))
  
    cornerToRadius2 = t.distanceToSquared(corner)
    if isInner
      return if cornerToRadius2 < radius2

    cornerLocal = @localPositionAt(corner)
    stretchVertex = _.min(vertices, (v) -> v.distanceToSquared(cornerLocal))
    stretchVertex.copy cornerLocal

    if (@stretchVertex? and @stretchVertex != stretchVertex) or
       (Math.abs(stretchVertex.distanceToSquared(stretchVertex.was)) > holdDistanceToSquared)
      @stretchVertex = null
      @reset()
    else
      @stretchVertex = stretchVertex
      v.copy(v.was) for v in vertices when not v.equals(stretchVertex)
      if stretchVertex.tween
        stretchVertex.tween.stop()
        stretchVertex.tween = null

  reset: ->
    that = this
    that.canCollide = false
    promises = []
    _.each @shape.vertices, (v) -> 
      unless v.equals(v.was)
        v.tween.stop() if v.tween

        d = $.Deferred()
        v.tween = new TWEEN.Tween(x: v.x, y: v.y)
          .to({ x: v.was.x, y: v.was.y}, 500)
          .onUpdate ->
            v.set @x, @y
          .onComplete ->
            v.copy v.was
            d.resolve()
          .easing(TWEEN.Easing.Bounce.Out)
          .start()
        promises.push d.promise()

    $.when.apply($, promises).done ->
      that.canCollide = true

class CirclesView extends Backbone.View
  initialize: (options) ->
    @two = options.two

  render: ->
    two = @two
    @collection.each (circle) ->
      new CircleView(model: circle, two: two)

class WorldView extends Backbone.View
  el: 'body'

  initialize: ->
    Two.Resolution = 12;

    two = new Two(fullscreen: true, autostart: true).appendTo(@el)
    @listenTo two, 'update', ->
      TWEEN.update()

    circles = new Circles [
      { x: two.width / 2, y: two.height / 2, r: two.height / 3 }
    ]

    books = new Books [
      { title: 'ムーミン谷の冬', image_url: './img/m.jpg' }
    ]

    @listenTo books, 'change', (book) ->
      circles.each (circle) ->
        circle.collision book

    @circlesView = new CirclesView(collection: circles, two: two)
    @circlesView.render()

    @booksView   = new BooksView(collection: books)
    $('#draw').append @booksView.render().el

  worldPositionFromMouseEvent: (e) ->
    { x: e.pageX, y: e.pageY }

$ ->
  worldView = new WorldView
