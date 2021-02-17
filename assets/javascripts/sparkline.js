var sparkline = function (selector, server_name, data_url) {
  var margin = { top: 5, right: 5, bottom: 5, left: 5 },
    width = 200 - margin.left - margin.right,
    height = 25 - margin.top - margin.bottom;

  var parseDate = d3.time.format("%Y%m%d").parse;

  d3.json(data_url, function (error, data) {
    var data = data[server_name];

    // Stop now if no data
    if (!data) {
      return;
    }

    var data = data.map(function (d) {
      return {
        date: parseDate(d.date),
        count: +d.count,
      };
    });

    var today = parseDate(
      new Date().toISOString().slice(0, 10).replaceAll("-", "")
    );
    var x = d3.time
      .scale()
      .domain([
        d3.max(
          data.map(function (d) {
            return d.date;
          })
        ),
        today,
      ])
      .range([0, width]);

    var y = d3.scale
      .linear()
      .domain(
        d3.extent(
          data.map(function (d) {
            return d.count;
          })
        )
      )
      .range([height, 0]);

    var line = d3.svg
      .line()
      .interpolate("linear")
      .x(function (d) {
        return x(d.date);
      })
      .y(function (d) {
        return y(d.count);
      });

    var svg = d3
      .select(selector)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    svg
      .append("path")
      .datum(data)
      .attr("fill", "none")
      .attr("stroke", "green")
      .attr("stroke-width", 1.5)
      .attr("stroke-linejoin", "round")
      .attr("stroke-linecap", "round")
      .attr("d", line);
  });
};
