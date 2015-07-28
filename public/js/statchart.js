var statchart = statchart || {};

statchart.add = function(selector, json)
{
  var parseDate = d3.time.format("%Y%m%d").parse;

  var data = json.map(function(d) {
    return {
      'date' : parseDate(d.date),
      'count' : d.count
    };
  });

  var margin = { 'top' : 15, 'right' : 25, 'bottom' : 25, 'left' : 45 },
      width = 230,
      height = 150;
        var x = d3.time.scale()
    .range([0, width])
    .domain(d3.extent(data, function(d) { return d.date; }));;

  var y = d3.scale.linear()
    .range([height, 0])
    .domain([0, d3.max(data.map(function(d) { return d.count; }))])

  var xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom");

  var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left");

  var line = d3.svg.line()
    .x(function(d) { return x(d.date); })
    .y(function(d) { return y(d.count); });
    
    
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

  var line = d3.svg.line()
    .interpolate("linear")
    .x(function(d) { return x(d.date); })
    .y(function(d) { return y(d.count); })

  svg.append("path")
    .datum(data)
    .attr("class", "line")
    .attr("d", line);

}
