var popchart = function(selector, data_url)
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


  d3.json(data_url, function(error, data) {
    color.domain(d3.keys(data))

    // Re-structure and parse values
    var servers = color.domain().map(function(name) {
      return {
        name: name,
        values: data[name].map(function(count) {
          return { date: parseDate(count.date), count: +count.count };
        })
      };
    });

    // Find the min and max values for the scales
    // TODO: Consider a more efficient way to do this
    var xvals = [],
        yvals = [];

    servers.forEach(function(server) {
      var dates = server.values.map(function(data) {
        return data.date
      });

      var counts = server.values.map(function(data) {
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
        .attr("d", function(d) { return line(d.values); })
        .style("stroke", function(d) { return color(d.name); });

    server.append("text")
        .datum(function(d) { return {name: d.name, value: d.values[d.values.length - 1]}; })
        .attr("transform", function(d) { return "translate(" + x(d.value.date) + "," + y(d.value.count) + ")"; })
        .attr("x", 3)
        .attr("dy", ".35em")
        .attr("class", "label")
        .text(function(d) { return capitalize(d.name) + ": " + Math.round(d.value.count)})
        .style("fill", function(d) { return color(d.name); });

    // Perform constrain relaxation on text labels
    // https://www.safaribooksonline.com/blog/2014/03/11/solving-d3-label-placement-constraint-relaxing/

    var labels = d3.selectAll(".label"),
        alpha = 0.25,
        spacing = 2,
        maxcalls = 1000;

    var relax = function() {
      if(maxcalls <= 0) { return; }
      maxcalls -= 1;

      var again = false; // Set to true to re-run relaxation

      labels.each(function(d, i) {
        if(i == 1 || i == 9) { return; }
        var a = this,
            da = d3.select(a),
            y1 = da.attr("y");

        labels.each(function(d, i) {
          if(i == 1 || i == 9) { return; }

          var b = this;

          if(a == b) { return; }

          var db = d3.select(b),
              y2 = db.attr("y"),
              delta = y1 - y2;

          if (Math.abs(delta) > spacing) { return; }

          again = true;


          sign = delta > 0 ? 1 : -1;
          adjust = sign * alpha;
          da.attr("y",+ y1 + adjust);
          db.attr("y",+ y2 - adjust);

          if(again) { setTimeout(relax, 10); }
        });
      });
    };

    setTimeout(relax, 1000);
  });
}
