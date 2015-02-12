var width = 646,
    height = 646;

var cluster = d3.layout.cluster()
    .size([height-60, width-60]);

var diagonal = d3.svg.diagonal()
    .projection(function(d) { return [d.x, d.y]; });

var svg = d3.select("#tree").append("svg")
    .attr("width", width)
    .attr("height", height)
  .append("g")
    .attr("transform", "translate(0,40)");

// Process URL for server and name
var tokens = window.location.href.split("/"),
    request_url = ["/tree", [tokens[tokens.length - 2], tokens[tokens.length - 1]].join("-")].join("/");

d3.json(request_url, function(error, root) {
  var nodes = cluster.nodes(root),
      links = cluster.links(nodes);

  var link = svg.selectAll(".link")
      .data(links)
    .enter().append("path")
      .attr("class", "link")
      .attr("d", diagonal);

  var node = svg.selectAll(".node")
      .data(nodes)
    .enter().append("g")
      .attr("class", "node")
      .attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; })

  node.append("svg:a")
    .attr("xlink:href", function(d) { return ["/", tokens[tokens.length - 2], "/", d.name].join(""); })
    .append("circle")
      .attr("r", 6)
      .style("fill", function(d) { return d.name == tokens[tokens.length - 1] ? "gold" : "white"; });

  node.append("svg:a")
    .attr("xlink:href", function(d) { return ["/", tokens[tokens.length - 2], "/", d.name].join(""); })
    .append("text")
      .attr("dx", function(d) { return d.children ? 20 : 10; })
      .attr("dy", 4)
      .style("text-anchor", "start")
      .style("fill", function(d) { return d.name == tokens[tokens.length - 1] ? "gold" : "white"; })
      .text(function(d) { return d.name; });
});

d3.select(self.frameElement).style("height", height + "px");
