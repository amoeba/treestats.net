var visitPreOrder = function(root, callback) {
  callback(root)

  if (root.children) {
    for (var i = root.children.length - 1; i >= 0; i--){
     visitPreOrder(root.children[i], callback)
    };
  }
}

var draw = function(selector, json, server_name, player_name, options) {
  // Handle zooming
  var zoomed = function () {
    g.attr("transform", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")");
  }

  // Zoom to player's node by name
  var zoomTo = function(name) {
    var d = null;
    
    for(var i = 0; i < nodes.length; i++) {
      if(nodes[i].name == name) {
        d = nodes[i]
      }
    }
    
    if(d == null) return;
    
    var translate = [width/2 - d.y,  height/2 - d.x];

    svg.transition()
        .call(zoom.translate(translate).event);
  }

  var width = options.width || 300,
     height = options.height || 300;

  var cluster = d3.layout.cluster()
    .size([width, height]);
    
  var nodes = cluster.nodes(json)
      links = cluster.links(nodes);

  // Calculate root distances (root = 1)
  visitPreOrder(nodes[0], function(node) {
    node.rootDist = (node.parent ? node.parent.rootDist : 0) + 1
  })

  var rootDists = nodes.map(function(n) { return n.rootDist; });

  // Calculate virtual canvas size
  var fixedDepth = 150;
  var virtualSize = [d3.max(rootDists) * fixedDepth, height];
  
  cluster.size(virtualSize);

  var diagonal = d3.svg.diagonal()
    .projection(function(d) { return [d.y, d.x]; });

  var zoom = d3.behavior.zoom()
    .translate([0,0])
    .scale(1)
    .scaleExtent([.8, 2])
    .on("zoom", zoomed);
    
  var svg = d3.select(selector).append("svg")
    .attr("width", width)
    .attr("height", height);
  
  svg.append("rect")
    .attr("class", "overlay")
    .attr("width", width)
    .attr("height", height);
    
  var g = svg.append("g");
  
  svg.
    call(zoom).
    call(zoom.event);

  // Normalize so each level is 150px away from the adjacent one
  nodes.forEach(function(d) { d.y = d.rootDist * fixedDepth; });

  var link = g.selectAll(".link")
    .data(links)
    .enter().append("path")
      .attr("class", "link")
      .attr("d", diagonal)
      .attr("fill", function(d) { return "none"; })
      .attr("stroke", function(d) { return "#AAA"; })
      .attr("stroke-width", function(d) { return "1px"; });

  var node = g.selectAll(".node")
    .data(nodes)
    .enter().append("g")
      .attr("class", "node")
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })

  node.append("svg:a")
    .attr("xlink:href", function(d) { return ["/", server_name, "/", d.name].join(""); })
    .append("circle")
      .attr("r", 4.5)
      .style("fill", function(d) { return d.name == player_name ? "gold" : "black"; })
      .style("stroke", function(d) { return "white"; })
      .style("stroke-width", function(d) { return "1px"; });

  node.append("svg:a")
    .attr("xlink:href", function(d) { return ["/", server_name, "/", d.name].join(""); })
    .append("text")
      .attr("dx", function(d) { return d.children ? -8 : 8; })
      .attr("dy", 3)
      .style("text-anchor", function(d) { return d.children ? "end" : "start"; })
      .style("font-family", function(d) { return "'Open Sans', Sans-serif" })
      .style("font-size", function(d) { return "10px" })
      .style("fill", function(d) { return d.name == player_name ? "gold" : "white" })
      .text(function(d) { return d.name; });
    
  if(player_name) {
    zoomTo(player_name);
  }
};
