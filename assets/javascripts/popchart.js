var popchart = function (selector, data_url) {
  // Following code copied then adapted from http://bl.ocks.org/mbostock/3884955

  // Setup
  var margin = { top: 20, right: 120, bottom: 30, left: 50 },
    width = 960 - margin.left - margin.right,
    height = 960 - margin.top - margin.bottom;

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

    // End time series at today, even if date don't go up to it
    var today = parseDate((new Date()).toISOString().slice(0, 10).replaceAll("-", ""));
    x.domain([d3.min(xvals), today]);
    y.domain([0, d3.max(yvals) * 1.05]);

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
      .attr("x", function(d) { return x(d3.max(xvals))})
      .attr("y", function(d) { return y(d.value.count)})
      .attr("dx", ".35em")
      .attr("dy", ".35em")
      .attr("class", "label")
      .text(function (d) { return d.name + ": " + Math.round(d.value.count) })
      .style("fill", function (d) { return color(d.name); });

    // Total count
    var totalpop = servers.reduce(function(acc, x) { return acc + x.values[x.values.length - 1].count; }, 0)

    svg.append("text")
      .attr("class", "totalpop")
      .attr("x", x(d3.max(xvals)))
      .attr("y", 0)
      .text("Total: " + totalpop);

    /**
     * nudge labels so they don't overlap
     */
    var nudge = function (amount = 5) {
      var maxit = 50;

      var sorted = d3.selectAll(".label")[0].sort(function (a, b) {
        return d3.select(a).datum().value.count - d3.select(b).datum().value.count;
      });

      var any_intersected = true;

      while (any_intersected && maxit >= 0) {
        any_intersected = false;

        for (var i = 0; i < sorted.length; i++) {
          for (var j = i; j < sorted.length; j++) {
            // Skip the same label
            if (sorted[i] === sorted[j]) {
              continue;
            }

            if (intersects(sorted[i], sorted[j], 5)) {
              any_intersected = true;
              sorted[j].setAttribute("y", sorted[j].getAttribute("y") - amount);
            }
          }
        }

        --maxit;
      }

      return;
    }

    // Do two SVGRect's intersect?
    // Allows a fudge parameter to allow partial overlap
    var intersects = function(a, b, fudge = 0) {
      var rect1 = a.getBBox();
      var rect2 = b.getBBox();

      if (
        rect1.x < rect2.x + rect2.width &&
        rect1.x + rect2.width > rect2.x &&
        rect1.y < rect2.y + rect2.height - fudge &&
        rect1.y + rect1.height - fudge > rect2.y
      ) {
        return true;
      }

      return false;
    }

    setTimeout(nudge, 150);
  });
}
