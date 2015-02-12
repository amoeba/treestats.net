d3.allegiancetree = {}

d3.allegiancetree.rightAngleDiagonal = function() {
  var projection = function(d) { return [d.x, d.y]; }

  var path = function(pathData) {
    return "M" + pathData[0] + ' ' + pathData[1] + ' ' + pathData[2] + ' ' + pathData[3];
  }

  function diagonal(diagonalPath, i) {
    var source = diagonalPath.source,
        target = diagonalPath.target,
        tagend = 0.10 * (target.x - source.x),
        pathData = [source, {x: source.x, y: source.y + (0.15 * (target.y - source.y))}, {x: target.x, y: source.y + (0.15 * (target.y - source.y))}, target];

    pathData = pathData.map(projection);

    return path(pathData)
  }

  return diagonal;
}

d3.allegiancetree.build = function(selector, nodes, options) {
  options = options || {}

  var w = options.width || d3.select(selector).style('width') || d3.select(selector).attr('width'),
      h = options.height || d3.select(selector).style('height') || d3.select(selector).attr('height'),
      w = parseInt(w),
      h = parseInt(h);

  var tree = d3.layout.cluster()
    .size([w, h])
    .separation(function(a, b) {
      return a.name.length
    });

  var diagonal = d3.allegiancetree.rightAngleDiagonal();

  var vis = d3.select(selector).append("svg:svg")
      .attr("width", w)
      .attr("height", h)
    .append("svg:g")
      .call(d3.behavior.zoom().scaleExtent([0.5,5]).on("zoom", function() {
        vis.attr("transform", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")");
      }))
    .append("svg:g")
      .attr("transform", "translate(0, 0)");

  vis.append("rect")
    .attr("class", "overlay")
    .attr("width", w + w/2)
    .attr("height", h + h/2);

  var nodes = tree(nodes);

  // Visit all nodes and adjust y pos width distance metric
  var visitPreOrder = function(root, callback) {
    callback(root)

    if (root.children) {
      for (var i = root.children.length - 1; i >= 0; i--){
        visitPreOrder(root.children[i], callback)
      };
    }
  }
  visitPreOrder(nodes[0], function(node) {
    node.rootDist = (node.parent ? node.parent.rootDist : 0) + 1
  })

  var rootDists = nodes.map(function(n) { return n.rootDist; });

  var yscale = d3.scale.linear()
    .domain([0, d3.max(rootDists)])
    .range([0, w]);

  visitPreOrder(nodes[0], function(node) {
    node.y = yscale(node.rootDist)
  })

  var link = vis.selectAll("path.link")
      .data(tree.links(nodes))
    .enter().append("svg:path")
      .attr("class", "link")
      .attr("d", diagonal)
      .attr("fill", "none")
      .attr("stroke", "#ccc")
      .attr("stroke-width", "1.5px");

  var node = vis.selectAll("g.node")
    .data(nodes)
    .enter().append("svg:g")
      .attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; })

  node.append("svg:a")
    .attr("xlink:href", function(d) { return ["/", server_name, "/", d.name].join(""); })
    .append("svg:text")
      .attr("dx", function(d) { return d.rootDist == 1 ? 0 : 10; })
      .attr("dy", function(d) { return d.rootDist == 1 ? -12 : 6; })
      .attr("text-anchor", function(d) { return d.rootDist == 1 ? "middle" : "start"; })
      .attr('font-family', 'Open Sans', 'Helvetica Neue, Helvetica, sans-serif')
      .attr('font-size', '10px')
      .attr('fill', function(d) { return d.name == player_name ? "gold" : "white"; })
      .attr('font-weight', function(d) { return d.name == player_name ? "bold" : "normal"; })
      .attr('background-color', 'white')
      .text(function(d) { return d.name.split(" ").join("\r\n"); })
      .attr("transform", function(d) { return d.rootDist == 1 ? "rotate(0)" : "rotate(45)"});


  node.append("svg:a")
    .attr("xlink:href", function(d) { return ["/", server_name, "/", d.name].join(""); })
    .append("svg:circle")
      .attr("r", 4.5)
      .attr('stroke', function(d) { return d.name == player_name ? "gold" : "black"; })
      .attr('fill', function(d) { return d.name == player_name ? "gold" : "white"; })
      .attr('stroke-width', '1px');
}
