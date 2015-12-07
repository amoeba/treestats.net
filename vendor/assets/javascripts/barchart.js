// Based on "Let's Make a Bar Chart by Mike Bostock
// http://bl.ocks.org/mbostock/3885304
// http://bost.ocks.org/mike/chart/time-series-chart.js

function barchart() {
  var margin = { 'top': 30, 'right': 20, 'bottom': 20, 'left': 120},
  width =  600,
  height = 400,
  xValue = function(d) { return d.x; },
  yValue = function(d) { return d.y; },
  sort = 'ascending' // natural, ascending, descending, Array
  trim = 20; // trim to first n records, after sorting (0 = no trim)

  function chart(selection) {
    selection.each(function(data, error) {
      // http://bost.ocks.org/mike/chart/time-series-chart.js
      // Convert data to standard representation greedily;
      // this is needed for nondeterministic accessors.
       data = data.map(function(d, i) {
         return {'x': xValue.call(data, d, i), 'y': yValue.call(data, d, i)};
       });

      // Step 1/4: Sort
      if(sort != 'natural') {
        if(Array.isArray(sort) && sort.length > 0) {
          data = data
        } else {
          if(sort == 'ascending') {
            data = data.sort(function(a, b) { return b.y - a.y });
          } else if (sort == 'descending') {
            data = data.sort(function(a, b) { return a.y - b.y });
          }
        }
      }

      // Step 2/4: Trim
      if(trim > 0) {
        if(data.length >= trim) {
          data = data.slice(0, (trim - 1));
        }
      }

      // Step 3/4: Adjust margin by the length of the longest x value
      longest_x = d3.max(data, function(d) { return (d.x + "").length; })
      margin.left = 20 + 8 * longest_x

      // Step 4/4 Plot
      var x = d3.scale.ordinal()
          .domain(data.map(function(d) { return d.x; }))
          .rangeRoundBands([0, height]);

      var y = d3.scale.linear()
          .domain([0, d3.max(data, function(d) { return d.y; })])
          .range([0, width]);

      var xAxis = d3.svg.axis()
          .scale(x)
          .orient("left");

      var y_axis_tick_count = Math.floor(height / 80);
      if(y_axis_tick_count <= 1) {
        y_axis_tick_count = 2
      }

      var yAxis = d3.svg.axis()
          .scale(y)
          .orient("top")
          .ticks(y_axis_tick_count);

      var svg = d3.select(this).append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
          .attr("width", width + margin.left + margin.right)
          .attr("height", height + margin.top + margin.bottom)
          .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
      svg.append("g")
          .attr("class", "x axis")
          .call(xAxis);

      svg.append("g")
          .attr("class", "y axis")
          .call(yAxis);

      var bar = svg.selectAll(".bar")
        .data(data)
      .enter().append("rect")
        .attr("class", "bar")
        .attr("x", function(d) { return y(0)})
        .attr("y", function(d) { return x(d.x)})
        .attr("height", x.rangeBand())
        .attr("width", function(d) { return y(d.y)})
        .on("mouseover", function(d) {
          tooltip
            .style("opacity", 1)
            .html(d.x + ": " + d.y)
            .style("left", (d3.event.pageX) + "px")
            .style("top", (d3.event.pageY) + "px")
         })
        .on("mouseout", function(d) {
          tooltip
            .style("opacity", 0)
            .html("")
         });

      // Tooltips
      var tooltip = d3.select("body").append("div")
        .attr("class", "tooltip")
        .style("opacity", 0)
    });
  }

  chart.width = function(value) {
    if (!arguments.length) return width;
    width = value;
    return chart;
  };

  chart.height = function(value) {
    if (!arguments.length) return height;
    height = value;
    return chart;
  };

  chart.x = function(value) {
    if (!arguments.length) return x;
    x = value;
    return chart;
  };

  chart.y = function(value) {
    if (!arguments.length) return y;
    y = value;
    return chart;
  };

  chart.sort = function(value) {
    if (!arguments.length) return sort;
    sort = value;
    return chart
  }

  chart.trim = function(value) {
    if (!arguments.length) return trim;
    trim  = value;
    return chart;
  };

  return chart;
}
