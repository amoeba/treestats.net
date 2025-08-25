// Summary chart for ranking data distributions
// Based on existing barchart.js pattern

function summary_chart() {
  var margin = { 'top': 20, 'right': 20, 'bottom': 30, 'left': 20 },
    height = 135,
    labelValue = function (d) { return d.label; },
    countValue = function (d) { return d.count; },
    showYAxis = false;

  function chart(selection) {
    selection.each(function (data, error) {
      // Get the container width dynamically
      var containerWidth = parseInt(d3.select(this).style('width'), 10) || 600;
      var width = containerWidth - margin.left - margin.right;

      // Adjust margins based on y-axis visibility and number of groups
      if (showYAxis) {
        margin.left = 60;
        width = containerWidth - 60 - margin.right;
      } else {
        margin.left = 20;
        width = containerWidth - 20 - margin.right;
      }

      // Increase bottom margin for rotated labels
      if (data.length > 10) {
        margin.bottom += 40;
      }
      // Convert data to standard representation
      data = data.map(function (d, i) {
        var label = labelValue.call(data, d, i);
        // Replace "Other" with "?"
        if (label === "Other") {
          label = "?";
        }
        return { 'label': label, 'count': countValue.call(data, d, i) };
      });

      // Filter out zero counts and sort by label value (numeric if possible, then alphabetic)
      data = data.filter(function (d) { return d.count > 0; });
      data = data.sort(function (a, b) {
        // Try to parse as numbers first
        var aNum = parseFloat(a.label);
        var bNum = parseFloat(b.label);

        if (!isNaN(aNum) && !isNaN(bNum)) {
          return aNum - bNum; // Numeric sort ascending
        } else {
          // If either isn't a number, sort alphabetically
          return a.label.toString().localeCompare(b.label.toString());
        }
      });

      // Set up scales (swapped from horizontal to vertical)
      var x = d3.scale.ordinal()
        .domain(data.map(function (d) { return d.label; }))
        .rangeRoundBands([0, width], 0.3);

      var y = d3.scale.linear()
        .domain([0, d3.max(data, function (d) { return d.count; })])
        .range([height, 0]);

      // Set up axes
      var xAxis = d3.svg.axis()
        .scale(x)
        .orient("bottom");

      var y_axis_tick_count = Math.floor(height / 40);
      if (y_axis_tick_count <= 1) {
        y_axis_tick_count = 2;
      }

      var yAxis = d3.svg.axis()
        .scale(y)
        .orient("left")
        .ticks(y_axis_tick_count);

      // Create SVG
      var svg = d3.select(this).append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      // Add axes
      var xAxisGroup = svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis);

      // Rotate labels if there are more than 10 groups
      if (data.length > 10) {
        xAxisGroup.selectAll("text")
          .style("text-anchor", "end")
          .attr("dx", "-.8em")
          .attr("dy", "-.2em")
          .attr("transform", "rotate(-90)");
      }

      // Conditionally add y-axis
      if (showYAxis) {
        svg.append("g")
          .attr("class", "y axis")
          .call(yAxis);
      }

      // Tooltip
      var tooltip = d3.select("body").append("div")
        .attr("class", "tooltip")
        .style("opacity", 0);

      // Create bars (vertical bars)
      var bar = svg.selectAll(".bar")
        .data(data)
        .enter().append("rect")
        .attr("class", "bar")
        .attr("x", function (d) { return x(d.label); })
        .attr("y", function (d) { return y(d.count); })
        .attr("width", x.rangeBand())
        .attr("height", function (d) { return height - y(d.count); })
        .on("mouseover", function (d) {
          tooltip
            .style("opacity", 1)
            .html(d.label + ": " + d.count.toLocaleString())
            .style("left", (d3.event.pageX) + "px")
            .style("top", (d3.event.pageY) + "px");
        })
        .on("mouseout", function (d) {
          tooltip
            .style("opacity", 0)
            .html("");
        });
    });
  }


  chart.height = function (value) {
    if (!arguments.length) return height;
    height = value;
    return chart;
  };

  chart.margin = function (value) {
    if (!arguments.length) return margin;
    margin = value;
    return chart;
  };

  chart.showYAxis = function (value) {
    if (!arguments.length) return showYAxis;
    showYAxis = value;
    return chart;
  };

  return chart;
}
