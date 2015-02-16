var popchart = {}

popchart.add = function(selector, server, data)
{
  var server = server || "unknown";

  var parse = function(timestamp) { return new Date(timestamp); }

  var values = data.map(function(d) { return {
    'timestamp' : parse(d.timestamp), 
    'count' : d.count};
  });
  
  var customTimeFormat = d3.time.format.multi([
    [".%L", function(d) { return d.getMilliseconds(); }],
    [":%S", function(d) { return d.getSeconds(); }],
    ["%I:%M", function(d) { return d.getMinutes(); }],
    ["%I %p", function(d) { return d.getHours(); }],
    ["%a %d", function(d) { return d.getDay() && d.getDate() != 1; }],
    ["%b %d", function(d) { return d.getDate() != 1; }],
    ["%B", function(d) { return d.getMonth(); }],
    ["%Y", function() { return true; }]
  ]);
  
  var margin = { 'top' : 35, 'right' : 15, 'bottom' : 30, 'left' : 45 },
      width = 300,
      height = 150;
    
  var xvals = values.map(function(r) { return r.timestamp; });
  var yvals = values.map(function(r) { return r.count; });
  
  // Custom domains, highly experimental
  var xDomainStart = Date.parse(d3.min(xvals).getFullYear()) - 1000 * 60 * 60 * 24 * 7,
      maxDate = d3.max(xvals),
      xDomainEnd = Date.parse((maxDate.getFullYear()) + "/" + (maxDate.getMonth() + 1) + "/1") + 1000 * 60 * 60 * 24 * 31

  var x = d3.time.scale()
    .domain([xDomainStart, xDomainEnd])
    .range([0, width]);
    
  var y = d3.scale.linear()
    .domain([0, d3.max(yvals)])
    .range([height, 0])
    .nice();

  var xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")
    .tickFormat(customTimeFormat)
    .ticks(2);
    
  var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left");
      

  var svg = d3.select(selector).append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  // Tooltips
  var tooltip = d3.select("body")
      .append("div")
      .attr("id", "tooltip")
      .style("position", "absolute")
      .style("z-index", "10")
      .style("opacity", 0);

  function onMouseOver(d) {
    d3.select(this).attr("fill","black")
         
    tooltip.html(d.count);
    
    return tooltip
      .transition()
      .duration(250)
      .style("opacity", 0.9);
  }

  function onMouseOut(){
    d3.select(this).attr("fill","white")
    return tooltip
      .transition()
      .duration(250)
      .style("opacity", 0);
  }

  function onMouseMove (d) {
    return tooltip
      .style("top", (d3.event.pageY + 5)+"px")
      .style("left", (d3.event.pageX + 10)+"px");
  }

      
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
      .attr("class", "axislabel")
      .text("Players")
      .attr("text-anchor", "end")
      .attr("transform", "translate(0,-15)")
    
  //Add lines
  var line = d3.svg.line()
    .interpolate("linear")
    .x(function(d) { return x(d.timestamp); })
    .y(function(d) { return y(d.count); })
    
  svg.selectAll("path")
    .data(values)
    .enter()
    .append("path")  
    .attr("class", "line")
    .attr("d", line(values))
    .on("mouseover", onMouseOver)
    .on("mousemove", onMouseMove)
    .on("mouseout", onMouseOut);
}