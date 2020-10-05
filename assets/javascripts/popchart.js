var popchart = function (selector, data_url) {
  // Following code copied then adapted from http://bl.ocks.org/mbostock/3884955

  // Setup
  var margin = { top: 20, right: 120, bottom: 30, left: 50 },
    width = 960 - margin.left - margin.right,
    height = 500 - margin.top - margin.bottom;

  var parseDate = d3.time.format("%Y%m%d").parse;
  var capitalize = function (s) { return s[0].toUpperCase() + s.slice(1); }

  var x = d3.time.scale()
    .range([0, width]);

  var y = d3.scale.linear()
    .range([height, 0]);

  var color = d3.scale.category20();

  var xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom");

  var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left");

  var line = d3.svg.line()
    .interpolate("linear")
    .x(function (d) { return x(d.date); })
    .y(function (d) { return y(d.count); });

  var svg = d3.select(selector).append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  // Loading indicator
  svg.append("text")
    .attr("x", width / 2)
    .attr("y", height / 2)
    .attr("class", "removeme flash")
    .style("font-size", "100%")
    .text("Loading...")

  d3.json(data_url, function (error, data) {
    // Handle error state
    if (error) {
      var removeEl = document.querySelectorAll(".removeme");

      if (removeEl.length != 1) {
        return;
      }

      removeEl[0].innerHTML = error.response;
      removeEl[0].classList.remove("flash");

      return;
    }

    // Handle no results
    if (Object.keys(data).length === 0) {
      var removeEl = document.querySelectorAll(".removeme");

      if (removeEl.length != 1) {
        return;
      }

      removeEl[0].innerHTML = "No data found. Try changing your filters.";
      removeEl[0].classList.remove("flash");

      return;
    }

    // Remove loading text
    svg.select(".removeme").remove();

    color.domain(d3.keys(data))

    // Re-structure and parse values
    var servers = color.domain().map(function (name) {
      return {
        name: name,
        values: data[name].map(function (count) {
          return { date: parseDate(count.date), count: +count.count };
        })
      };
    });

    // Find the min and max values for the scales
    // TODO: Consider a more efficient way to do this
    var xvals = [],
      yvals = [];

    servers.forEach(function (server) {
      var dates = server.values.map(function (data) {
        return data.date
      });

      var counts = server.values.map(function (data) {
        return data.count
      });

      xvals = xvals.concat(dates);
      yvals = yvals.concat(counts);
    });

    x.domain(d3.extent(xvals));
    y.domain([0, d3.max(yvals) * 1.25]);

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
      .attr("d", function (d) { return line(d.values); })
      .style("stroke", function (d) { return color(d.name); });

    server.append("text")
      .datum(function (d) { return { name: d.name, value: d.values[d.values.length - 1] }; })
      .attr("transform", function (d) { return "translate(" + x(d.value.date) + "," + y(d.value.count) + ")"; })
      .attr("x", 3)
      .attr("dy", ".35em")
      .attr("class", "label")
      .text(function (d) { return capitalize(d.name) + ": " + Math.round(d.value.count) })
      .style("fill", function (d) { return color(d.name); });
  });
}
