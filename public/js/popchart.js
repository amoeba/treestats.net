var popchart = popchart || {};

popchart.add = function(selector, json)
{
  var parse = function(timestamp) { return new Date(timestamp); }

  var data = json.map(function(d) {
    return {
      'date' : parse(d.c_at),
      'day'       : '',
      'count' : d.c,
      'server' : d.s
    };
  });

  // Add in 'days' (%Y-%m-%d format)
  for(var i = 0; i < data.length; i++) {
    var t = data[i].date;

    data[i].day = new Date(t.getFullYear(), t.getMonth(), t.getDate(), 12);
  }

  var servers = d3.set(data.map(function(d) { return d.server; })).values();
  var unique_days = d3.set(data.map(function(d) { return d.day; })).values().map(function(d) { return new Date(d); });

  var values = servers.map(function(s) {
    var server_days = d3.set(data
      .filter(function(d) { return d.server == s; })
      .map(function(d) { return d.day; }))
    .values()
    .map(function(d) { return new Date(d); });

    return {
      'server' : s,
      'values' : server_days.map(function(day) {
        var counts = [];

        for(var i= 0; i < data.length; i++) {
          if(data[i].server == s && data[i].day.getTime() == day.getTime()) {
            counts.push(data[i].count);
          }
        }

        return {
          'server' : s,
          'day'  : day,
          'mean' : d3.mean(counts)
        }
      })
    }
  });

  var margin = { 'top' : 35, 'right' : 80, 'bottom' : 30, 'left' : 45 },
      width = 600,
      height = 400;

  var xvals = unique_days;
  var yvals = data.map(function(v) { return v.count; });

  var x = d3.time.scale()
    .domain(d3.extent(xvals))
    .range([0, width]);

  var y = d3.scale.linear()
    .domain([0, d3.max(yvals)])
    .range([height, 0])
    .nice();

  var color = d3.scale.category10()
    .domain(servers);

  var xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")
    .ticks(5);

  var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left");

  var svg = d3.select(selector).append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  // Add x axis
  svg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0, " + height + ")")
    .call(xAxis)

  // Add y axis
  svg.append("g")
    .attr("class", "y axis")
    .attr("transform", "translate(0,0)")
    .call(yAxis)
    .append("text")
      .attr("class", "label")
      .text("Players")
      .attr("text-anchor", "end")
      .attr("transform", "translate(0,-15)");

  // Generators
  var line = d3.svg.line()
    .interpolate("linear")
    .x(function(d) { return x(d.day); })
    .y(function(d) { return y(d.mean); })

  // Mean Line Layer
  var server = svg.selectAll(".server")
    .data(values)
      .enter().append("g")
        .attr("class", "server");

  server.append("path")
    .attr("class", "line")
    .attr("d", function(d) { return line(d.values); })
    .style("stroke", function(d) { return color(d.server); })
    .style("opacity", 1);

  server.append("text")
    .attr("class", "text")
    .datum(function(d) { return { server: d.server, value: d.values[d.values.length - 1]}; })
    .attr("transform", function(d) { return "translate(" + x(d.value.day) + "," + y(d.value.mean) + ")"; })
    .attr("dx", function(d) { return 10 })
    .attr("dy", function(d) { return ( 20 * (Math.random() - 0.5)); })
    .text(function(d) { return d.server; })
    .style("fill", function(d) { return color(d.server); });
}
