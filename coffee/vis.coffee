
class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 700
    @height = 300

    @tooltip = CustomTooltip("twitter_tooltip", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2, y: @height / 2}
    @top_conv_centers = {
      "High tweet rate": {x: @width / 5, y: @height / 2},
      "Medium tweet rate": {x: @width / 2, y: @height / 2},
      "Low tweet rate": {x: 2 * @width / 2.5, y: @height / 2}
    }

    # used when setting up force and
    # moving around nodes
    @layout_gravity = -0.01
    @damper = 0.1

    # these will be set in create_nodes and create_vis
    @vis = null
    @nodes = []
    @force = null
    @circles = null

    # node colors
    @fill_color = d3.scale.ordinal()
      .domain(["low", "medium", "high"])
      .range(["#d6d60d", "#0099cc", "#ff0033"])

    # use the max total_amount in the data as the max in the scale's domain
    max_amount = d3.max(@data, (d) -> d.total_amount)
    @radius_scale = d3.scale.pow().exponent(0.5).domain([0, max_amount]).range([1, 10])
    
    this.create_nodes()
    this.create_vis()

  # create node objects from original data
  # that will serve as the data behind each
  # bubble in the vis, then add each node
  # to @nodes to be used later
  create_nodes: () =>
    @data.forEach (d) =>
      node = {
        id: d.id
        radius: @radius_scale(d.total_amount)
        value: d.total_amount
        name: d.tweet_rate
        org: d.organization
        group: d.tweet_amount
        top_conv: d.top_conv
        x: Math.random() * 900
        y: Math.random() * 800
      }
      @nodes.push node

    @nodes.sort (a,b) -> b.value - a.value


  # create svg at #vis and then 
  # create circle representation for each node
  create_vis: () =>
    @vis = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    @circles = @vis.selectAll("circle")
      .data(@nodes, (d) -> d.id)

    # used because we need 'this' in the 
    # mouse callbacks
    that = this

    # radius will be set to 0 initially.
    # see transition below
    @circles.enter().append("circle")
      .attr("r", 0)
      .attr("fill", (d) => @fill_color(d.group))
      .attr("stroke-width", 2)
      .attr("stroke", (d) => d3.rgb(@fill_color(d.group)).brighter(5))
      .attr("id", (d) -> "bubble_#{d.id}")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))

    # Fancy transition to make bubbles appear, ending with the
    # correct radius
    @circles.transition().duration(2000).attr("r", (d) -> d.radius)


  # Charge function that is called for each node.
  # Charge is proportional to the diameter of the
  # circle (which is stored in the radius attribute
  # of the circle's associated data.
  # This is done to allow for accurate collision 
  # detection with nodes of different sizes.
  # Charge is negative because we want nodes to 
  # repel.
  # Dividing by 8 scales down the charge to be
  # appropriate for the visualization dimensions.
  charge: (d) ->
    -Math.pow(d.radius, 2.0) / 8

  # Starts up the force layout with
  # the default values
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

  # Sets up force layout to display
  # all nodes in one circle.
  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.hide_top_convs()

  # Moves all circles towards the @center
  # of the visualization
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

  # sets the display of bubbles to be separated
  # into each top_conv. Does this by calling move_towards_top_conv
  display_by_top_conv: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_top_conv(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.display_top_convs()

  # move all circles to their associated @top_conv_centers 
  move_towards_top_conv: (alpha) =>
    (d) =>
      target = @top_conv_centers[d.top_conv]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

 
  



  # Method to display top_conv titles
  display_top_convs: () =>
    top_convs_x = {"High tweet rate": 100, "Medium tweet rate": @width / 2, "Low tweet rate": @width - 100}
    top_convs_data = d3.keys(top_convs_x)
    top_convs = @vis.selectAll(".top_convs")
      .data(top_convs_data)

    top_convs.enter().append("text")
      .attr("class", "top_convs")
      .attr("x", (d) => top_convs_x[d] )
      .attr("y", 40)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide top_conv titiles
  hide_top_convs: () =>
    top_convs = @vis.selectAll(".top_convs").remove()

  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = "<span class=\"name\">Twitter User:</span><span class=\"value\"> #{data.name}</span><br/>"
    content +="<span class=\"name\">Number of Tweets:</span><span class=\"value\"> #{addCommas(data.value)}</span><br/>"
    content +="<span class=\"name\">Tweet Frequency:</span><span class=\"value\"> #{data.top_conv}</span>"
    @tooltip.showTooltip(content,d3.event)


  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker(5))
    @tooltip.hideTooltip()


root = exports ? this

$ ->
  chart = null

  render_vis = (csv) ->
    chart = new BubbleChart csv
    chart.start()
    root.display_all()
  root.display_all = () =>
    chart.display_group_all()
  root.display_top_conv = () =>
    chart.display_by_top_conv()
  root.toggle_view = (view_type) =>
    if view_type == 'top_conv'
      root.display_top_conv()
    else
      root.display_all()

  d3.csv "data/ched-evans.csv", render_vis
