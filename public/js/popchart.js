var popchart = function(selector, data)
{
  // Following code copied then adapted from http://bl.ocks.org/mbostock/3884955

  // Setup
  var margin = {top: 20, right: 120, bottom: 30, left: 50},
      width = 960 - margin.left - margin.right,
      height = 500 - margin.top - margin.bottom;

  var parseDate = d3.time.format("%Y%m%d").parse;
  var capitalize = function(s) { return s[0].toUpperCase() + s.slice(1); }

  var x = d3.time.scale()
      .range([0, width]);

  var y = d3.scale.linear()
      .range([height, 0]);

  var color = d3.scale.category10();

  var xAxis = d3.svg.axis()
      .scale(x)
      .orient("bottom");

  var yAxis = d3.svg.axis()
      .scale(y)
      .orient("left");

  var line = d3.svg.line()
      .interpolate("linear")
      .x(function(d) { return x(d.date); })
      .y(function(d) { return y(d.count); });

  var svg = d3.select(selector).append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");


  // chart
  color.domain(d3.keys(data))

  var servers = color.domain().map(function(name) {
    return {
      name: name,
      values: d3.keys(data[name]).map(function(date) {
        return { date: parseDate(date), count: +data[name][date] };
      })
    };
  });

  xvals = []
  yvals = []

  servers.forEach(function(server) {
    dates = server.values.map(function(data) {
      return data.date
    });

    counts = server.values.map(function(data) {
      return data.count
    });

    x_extent = d3.extent(dates)
    y_max = d3.max(counts)

    xvals.push(x_extent[0])
    xvals.push(x_extent[1])

    yvals.push(y_max)
  });

  x.domain(d3.extent(xvals));

  y.domain([
      0,
      d3.max(yvals)
  ]);

  svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + height + ")")
      .call(xAxis);

  svg.append("g")
      .attr("class", "y axis")
      .call(yAxis)
    .append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", 6)
      .attr("dy", ".71em")
      .style("text-anchor", "end")
      .text("Players");

  var server = svg.selectAll(".server")
      .data(servers)
    .enter().append("g")
      .attr("class", "servers");

  server.append("path")
      .attr("class", "line")
      .attr("d", function(d) { return line(d.values); })
      .style("stroke", function(d) { return color(d.name); });

  server.append("text")
      .datum(function(d) { return {name: d.name, value: d.values[d.values.length - 1]}; })
      .attr("transform", function(d) { return "translate(" + x(d.value.date) + "," + y(d.value.count) + ")"; })
      .attr("x", 3)
      .attr("dy", ".35em")
      .text(function(d) { return capitalize(d.name) + ": " + Math.round(d.value.count)})
      .style("fill", function(d) { return color(d.name); });
}
