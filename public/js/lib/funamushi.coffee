vec2 = (x, y) -> new Two.Vector(x, y)

class Book extends Backbone.Model
  defaults:
    x: 0
    y: 0
    w: 0
    h: 0

class Books extends Backbone.Collection
  model: Book

class Circle extends Backbone.Model
  defaults: -> 
    x: 0
    y: 0
    r: 0
    books: new Books

class Circles extends Backbone.Collection
  model: Circle

class BookView extends Backbone.View
  tagName: 'img'
  className: 'book'

  initialize: ->
    @rect = {}

  attributes: ->
    style: 'display: inline-block; position: absolute; z-index: 1000;'
    src: @model.get('image_url')
    alt: @model.get('title')

  events:
    'drag': (e) ->
      @model.set(x: e.pageX, y: e.pageY)

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
    @two = options.two

    @shape = @two.makeCircle(@model.get('x'), @model.get('y'), @model.get('r'))
    @shape.linewidth = 1
    # @shape.noStroke()
    @shape.noFill()

    _.each @shape.vertices, (v) ->
      v.was = v.clone()

    @listenTo @model, 'collision', (rect) ->
      console.log('collision!!!!')

  resetColor: ->
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
    @shape.translation.distanceToSquared(worldPos) <= @radius * @radius

  collision: (worldPos) ->
    radius2 = @radius * @radius
    diffToSquared = @shape.translation.distanceToSquared(worldPos) - radius2
    if Math.abs(diffToSquared) > radius2 * 0.4
      @reset()
      return

    vertices = @shape.vertices
    localPos = @localPositionAt worldPos
    stretchVertex = _.min(vertices, (v) -> v.distanceToSquared(localPos))
    if stretchVertex.tween
      stretchVertex.tween.stop()
      stretchVertex.tween = null
    stretchVertex.copy(localPos)

    v.copy(v.was) for v in vertices when not v.equals(stretchVertex)

  reset: ->
    _.each @shape.vertices, (v) ->
      unless v.equals(v.was)
        v.tween.stop() if v.tween

        v.tween = new TWEEN.Tween(x: v.x, y: v.y)
          .to({ x: v.was.x, y: v.was.y}, 500)
          .onUpdate ->
            v.set @x, @y
          .onComplete ->
            v.copy v.was
          .easing(TWEEN.Easing.Bounce.Out)
          .start()

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
      console.log book

    @circlesView = new CirclesView(collection: circles, two: two)
    @circlesView.render()

    @booksView   = new BooksView(collection: books)
    $('#draw').append @booksView.render().el

  worldPositionFromMouseEvent: (e) ->
    { x: e.pageX, y: e.pageY }

$ ->
  worldView = new WorldView
