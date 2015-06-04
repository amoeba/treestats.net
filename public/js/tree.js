var draw = function(selector, json, server_name, allegiance_name, options) {
  var width = options.width || 800,
      height = options.height || 800;

  var svg = d3.select(selector).append("svg")
      .attr("width", width)
      .attr("height", height);

  var force = d3.layout.force()
      .gravity(.05)
      .distance(100)
      .charge(-200)
      .size([width, height]);

    force
        .nodes(json.nodes)
        .links(json.links)
        .start();
    
    var zoomed = function () {
      g.attr("transform", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")");
    }
  
    var zoom = d3.behavior.zoom()
      .translate([0,0])
      .scale(1)
      .scaleExtent([.8, 2])
      .on("zoom", zoomed);
      


    svg.append("rect")
      .attr("class", "overlay")
      .attr("width", width)
      .attr("height", height);
      
    var g = svg.append("g");
    
    svg.
      call(zoom).
      call(zoom.event);
    
    var link = g.selectAll(".link")
        .data(json.links)
      .enter().append("line")
        .attr("class", "link");

    var node = g.selectAll(".node")
        .data(json.nodes)
      .enter().append("g")
        .attr("class", "node")
        .call(force.drag);

    node.append("a")
      .attr("xlink:href", function(d) { return ["/", server_name, "/", d.name].join(""); })
      .append("text")
        .attr("dx", 12)
        .attr("dy", ".35em")
        .text(function(d) { return d.name });
        
    node.append("a")
      .attr("xlink:href", function(d) { return ["/", server_name, "/", d.name].join(""); })
      .append("circle")
        .attr("r", 4);

    force.on("tick", function() {
      link.attr("x1", function(d) { return d.source.x; })
          .attr("y1", function(d) { return d.source.y; })
          .attr("x2", function(d) { return d.target.x; })
          .attr("y2", function(d) { return d.target.y; });

      node.attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; });
  });
}