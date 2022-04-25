// Derived from https://observablehq.com/@d3/multi-line-chart

var popchart = function (selector, url) {
  const width = 960;
  const height = 640;
  const margin = { top: 60, right: 100, bottom: 60, left: 60 };
  const yLabel = "Population";
  const dateFormat = d3.timeFormat("%B %e, %Y");
  const messageClass = "status";
  const loadingClass = "flash";

  // Colors
  const mainColor = "white";
  const fadedColor = "rgba(220, 220, 220, 0.3)";

  const svg = d3.select(selector)
    .append("svg")
    .attr("width", width)
    .attr("height", height)
    .attr("viewBox", [0, 0, width, height])
    .attr("style", "max-width: 100%; height: auto; height: intrinsic;")
    .style("-webkit-tap-highlight-color", "transparent");

  // Loading / Error indicator
  svg.append("text")
    .attr("x", width / 2)
    .attr("y", height / 2)
    .attr("class", messageClass + " " + loadingClass)
    .style("font-size", "100%")
    .text("Loading...")

  function setStatus(message) {
    var messageEl = document.querySelectorAll(messageClass);

    if (messageEl.length != 1) {
      return;
    }

    messageEl[0].innerHTML = message;
    messageEl[0].classList.remove(loadingClass);
  }

  const draw = (data) => {
    if (data.length <= 0) {
      setStatus("No results to show. Try changing your filters.")
      return;
    }

    svg.select("." + messageClass).remove();

    const X = d3.map(data, x => x.date);
    const Y = d3.map(data, x => x.count);
    const Z = d3.map(data, x => x.server);
    const G = d3.group(data, d => d.server);
    const L = d3.map(G, ([s, v]) => {
      return {
        server: s,
        date: v[v.length - 1].date,
        count: v[v.length - 1].count
      }
    });

    // Domains
    const xDomain = d3.extent(X);
    const yDomain = [0, d3.max(Y)]

    // Ranges
    const xRange = [margin.left, width - margin.right];
    const yRange = [height - margin.top, margin.bottom];

    // Scales and axes
    const xScale = d3.scaleTime(xDomain, xRange);
    const yScale = d3.scaleLinear(yDomain, yRange);
    const xAxis = d3.axisBottom(xScale).ticks(width / 120).tickSizeOuter(0);
    const yAxis = d3.axisLeft(yScale).ticks(height / 60);

    // Line
    const line = d3.line()
      .curve(d3.curveLinear)
      .x(d => xScale(d.date))
      .y(d => yScale(d.count));

    // Draw xAxis
    svg.append("g")
      .attr("transform", `translate(0,${height - margin.bottom})`)
      .call(xAxis);

    // Draw yAxis
    svg.append("g")
      .attr("transform", `translate(${margin.left},0)`)
      .call(yAxis)
      .call(g => g.append("text")
        .attr("x", -margin.left)
        .attr("y", 10)
        .text(yLabel));

    // Draw lines
    const servers = svg.append("g")
      .selectAll("path")
      .data(G)
      .join("path")
      .attr("stroke", mainColor)
      .attr("fill", "none")
      .attr("d", ([, d]) => line(d));

    // Labels
    const labels = svg.append("g")
      .selectAll("text")
      .data(L)
      .join("text")
      .attr("x", d => xScale(d.date))
      .attr("y", d => yScale(d.count))
      .attr("dx", 4)
      .attr("dy", 4)
      .attr("font-family", "sans-serif")
      .attr("font-size", 10)
      .attr("text-anchor", "left")
      .text(d => d.server + ": " + d.count);

    // Draw dot
    const dot = svg.append("g")
      .attr("display", "none");

    dot.append("circle")
      .attr("r", 2.5)
      .attr("fill", mainColor);

    dot.append("text")
      .attr("font-family", "sans-serif")
      .attr("font-size", 10)
      .attr("fill", "gold")
      .attr("text-anchor", "middle")
      .attr("y", -8);

    // Set up input handlers
    svg
      .on("pointerenter", pointerentered)
      .on("pointermove", pointermoved)
      .on("pointerleave", pointerleft)
      .on("touchstart", event => event.preventDefault());

    // Interaction
    function pointermoved(event) {
      const [xm, ym] = d3.pointer(event);
      const i = d3.least(data, d => Math.hypot(xScale(d.date) - xm, yScale(d.count) - ym)); // closest point

      servers.style("stroke", ([server]) => i.server === server ? null : fadedColor).filter(([server]) => i.server === server).raise();
      labels.style("fill", d => i.server === d.server ? null : fadedColor).filter(d => i.server === d.server).raise();
      dot.attr("transform", `translate(${xScale(i.date)},${yScale(i.count)})`);
      dot.select("text").text(i.server + ": " + i.count + " on " + dateFormat(i.date));
    }

    function pointerentered() {
      servers.style("stroke", fadedColor);
      labels.style("fill", fadedColor);
      dot.attr("display", null);
    }

    function pointerleft() {
      servers.style("stroke", null);
      labels.style("fill", null);
      dot.attr("display", "none");
    }
  }

  const tidy = data => {
    return d3.map(data, d => {
      return {
        "date": d3.utcParse("%Y%m%d")(d.date),
        "count": d.count,
        "server": d.server
      }
    });
  }

  d3.json(url)
    .then(tidy)
    .then(draw)
    .catch(err => {
      setStatus(err.response);
    });
}
