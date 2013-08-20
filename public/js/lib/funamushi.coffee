vec2 = (x, y) -> new Two.Vector(x, y)

class Book extends Backbone.Model

class BookView extends Backbone.View
  tagName: 'img'
  className: 'book'

  initialize: ->
    @rect = {}

  attributes: ->
    style: 'position: absolute; z-index: 1000;'
    src: @model.get('image_url')
    alt: @model.get('title')

  events:
    'mousedown': (e) ->
      @hold = true
      @trigger 'hold', this

    'mouseup': (e) ->
      @hold = false

class CircleView extends Backbone.View
  el: 'body'

  events:
    'mousemove': (e) ->
      if @world.dragging
        @collision @world.worldPositionFromMouseEvent(e)

    'mouseup': (e) -> 
      @reset()

  initialize: (options) ->
    @world = options.world

    @radius = options.radius
    @shape = @world.two.makeCircle options.x, options.y, options.radius
    @shape.linewidth = 1
    # @shape.noStroke()
    @shape.noFill()

    _.each @shape.vertices, (v) ->
      v.was = v.clone()

    # @resetColor()

    # @listenTo @two, 'update', _.throttle(@resetColor, 500)
    # @listenTo @two, 'update', @update
    # @mutation()
    
    # Call only once a frame.
    # this.reset = _.debounce(_.bind(CircleView.prototype.reset, this), 0)

  resetColor: ->
    colors = [
      '#F4D6E0'
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

  localPositionFromMouseEvent: (e) ->
    localPositionAt @world.worldPositionFromMouseEvent(e)

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

  bounce: (worldPoint) ->
    localPoint = @localPositionAt worldPoint

    v = _.min(@shape.vertices, (v) -> d = v.distanceToSquared(localPoint))
    beforePos = { x: v.x, y: v.y }

    new TWEEN.Tween(x: localPoint.x, y: localPoint.y)
      .to({ x: v.x, y: v.y}, 500)
      .onUpdate ->
        v.x = @x
        v.y = @y
      .onComplete ->
        v.x = beforePos.x
        v.y = beforePos.y
      .easing(TWEEN.Easing.Elastic.InOut)
      .start()

  mutation: ->
    vertices = @shape.vertices
    n = vertices.length
    winWidth  = @world.two.width
    winHeight = @world.two.height

    @squished = false

    for i in [0...n]
      v = vertices[i]
      pct = (i + 1) / n
      theta = pct * Math.PI * 2
      radius = Math.random() * winHeight / 3 + winHeight / 6
      x = radius * Math.cos(theta)
      y = radius * Math.sin(theta)
      v.set(winHeight / 3 * Math.cos(theta), winHeight / 3 * Math.sin(theta))
      ( (v, x, y) ->
        tween = new TWEEN.Tween(x: v.x, y: v.y).to({x: x, y: y}, 2000)
        tween.onUpdate ->
          v.x = this.x
          v.y = this.y
        tween.easing TWEEN.Easing.Elastic.InOut
        tween.start()
      )(v, x, y)

    # @updateColor()

class WorldView extends Backbone.View
  el: 'body'

  events:
    'mousedown': ->
      @dragging = true

    'mousemove': (e) ->
      if @holdBookView
        worldPos = @worldPositionFromMouseEvent(e)
        @holdBookView.$el.css
          left: worldPos.x + 'px'
          top:  worldPos.y + 'px'

    'mouseup': ->
      @dragging = false
      @holdBook = null

  initialize: ->
    Two.Resolution = 12;

    @two = new Two(fullscreen: true, autostart: true).appendTo(@el)
    @listenTo @two, 'update', ->
      TWEEN.update()

    @circles = []

    @circleView = new CircleView
      world: this
      x: @two.width / 2
      y: @two.height / 2
      radius: @two.height / 3

    @book = new Book(title: 'ムーミン谷の冬', image_url: './img/m.jpg')
    @bookView = new BookView(model: @book)

    @listenTo @bookView, 'hold', (bookView) ->
      @holdBookView = bookView

    $('#draw').append @bookView.render().el

  worldPositionFromMouseEvent: (e) ->
    { x: e.pageX, y: e.pageY }

$ ->
  worldView = new WorldView
