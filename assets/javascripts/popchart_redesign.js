// Derived from https://observablehq.com/@d3/multi-line-chart

var popchart = function (selector, url) {
  const width = 960;
  const height = 640;
  const margin = { top: 60, right: 140, bottom: 60, left: 60 };
  const yLabel = "Population";
  const messageClass = "status";
  const loadingClass = "flash";

  // Colors
  const mainColor = "rgba(0, 180, 0, 0.8)";
  const fadedColor = "rgba(220, 220, 220, 0.3)";

  const svg = d3
    .select(selector)
    .append("svg")
    .attr("viewBox", [0, 0, width, height])
    .attr("preserveAspectRatio", "xMidYMid meet");

  // Loading / Error indicator
  svg
    .append("text")
    .attr("x", width / 2)
    .attr("y", height / 2)
    .attr("class", messageClass + " " + loadingClass)
    .style("font-size", "100%")
    .text("Loading...");

  function setStatus(message) {
    var messageEl = document.querySelectorAll("." + messageClass);

    if (messageEl.length != 1) {
      return;
    }

    messageEl[0].innerHTML = message;
    messageEl[0].classList.remove(loadingClass);
  }

  const draw = (data) => {
    if (data.length <= 0) {
      setStatus("No results to show. Try changing your filters.");
      return;
    }

    svg.select("." + messageClass).remove();

    // Start with X and Y so we can do scales first, then work on data
    const X = d3.map(data, (x) => x.date);
    const Y = d3.map(data, (x) => x.count);

    // Domains
    const xDomain = d3.extent(X);
    const yDomain = [0, d3.max(Y)];

    // Ranges
    const xRange = [margin.left, width - margin.right];
    const yRange = [height - margin.top, margin.bottom];

    // Scales and axes
    const xScale = d3.scaleTime(xDomain, xRange);
    const yScale = d3.scaleLinear(yDomain, yRange);

    // Now deal with the data transformation
    const Z = d3.map(data, (x) => x.server);
    const G = d3.group(data, (d) => d.server);
    const L = d3.map(G, ([s, v]) => {
      return {
        server: s,
        date: v[v.length - 1].date,
        count: v[v.length - 1].count,
      };
    });
    const LL = d3.map(G, ([s, v]) => {
      return {
        server: s,
        points: [
          [xScale(v[v.length - 1].date), yScale(v[v.length - 1].count)],
          [
            xScale(v[v.length - 1].date) + 100,
            yScale(v[v.length - 1].count + 10),
          ], // FIXME
        ],
      };
    });

    // Axes
    const xAxis = d3
      .axisBottom(xScale)
      .ticks(width / 120)
      .tickSizeOuter(0);

    const yAxis = d3.axisLeft(yScale).ticks(height / 60);

    // Line
    const line = d3
      .line()
      .curve(d3.curveNatural)
      .x((d) => xScale(d.date))
      .y((d) => yScale(d.count));

    // Line for label lines, this is semi-redundant with above
    const label_line = d3
      .line()
      .curve(d3.curveLinear)
      .x((d) => d[0])
      .y((d) => d[1]);

    // Draw xAxis
    svg
      .append("g")
      .attr("transform", `translate(0,${height - margin.bottom})`)
      .call(xAxis);

    // Draw yAxis
    svg
      .append("g")
      .attr("transform", `translate(${margin.left},0)`)
      .call(yAxis)
      .call((g) =>
        g.append("text").attr("x", -margin.left).attr("y", 10).text(yLabel)
      );

    // Draw lines
    const servers = svg
      .append("g")
      .selectAll("path")
      .data(G)
      .join("path")
      .attr("stroke", mainColor)
      .attr("fill", "none")
      .attr("d", ([, d]) => line(d));

    // Labels
    const labels = svg
      .append("g")
      .selectAll("text")
      .data(L)
      .join("a")
      // .attr("xlink:href", function (d) {
      //   return "/" + d.server;
      // })
      .append("text")
      .attr("class", "label")
      .attr("x", (d) => xScale(xDomain[1]))
      .attr("y", (d) => yScale(d.count))
      .attr("dx", 4)
      .attr("dy", 4)
      .attr("font-family", "sans-serif")
      .attr("font-size", 10)
      .attr("text-anchor", "left")
      .attr("data-server", (d) => d.server)
      .attr("data-date", (d) => d.date)
      .attr("data-count", (d) => d.count)
      .text((d) => d.server + ": " + d.count);

    // Lines from server lines to labels
    // const label_lines = svg
    //   .append("g")
    //   .selectAll("path")
    //   .data(LL)
    //   .join("path")
    //   .attr("class", "label_line")
    //   .attr("stroke", "red")
    //   .attr("fill", "none")
    //   .attr("d", (d) => label_line(d.points));

    // Draw dot
    const dot = svg.append("g").attr("display", "none");

    dot.append("circle").attr("r", 2.5).attr("fill", mainColor);

    dot
      .append("text")
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
      .on("touchstart", (event) => event.preventDefault());

    // Interaction
    function pointermoved(event) {
      const [xm, ym] = d3.pointer(event);

      // First, decide whether we're mousing over lines or line labels. We want
      // to find the nearest line or line label, then highlight the line and
      // line label for whatever server that is.

      // To decide whether we're hovering over lines or line labels, we just
      // need to compare our X value. If we're beyond the end of the X range of
      // the data points, we're nearer to line labels. Otherwise, we're nearer
      // to lines.

      let i;

      // TODO: This code could be DRY'd
      if (xm > xScale(d3.max(X))) {
        const label_nodes = d3.selectAll(".label").nodes();

        const closest_label = d3.least(label_nodes, (l) =>
          Math.hypot(l.getAttribute("x") - xm, l.getAttribute("y") - ym)
        );

        i = {
          server: closest_label.getAttribute("data-server"),
          date: closest_label.getAttribute("data-date"),
          count: closest_label.getAttribute("data-count"),
        };

        servers
          .style("stroke", ([server]) =>
            i.server === server ? null : fadedColor
          )
          .filter(([server]) => i.server === server)
          .raise();
        labels
          .style("fill", (d) => (i.server === d.server ? null : fadedColor))
          .filter((d) => i.server === d.server)
          .raise();
        dot.attr("display", "none");
      } else {
        i = d3.least(data, (d) =>
          Math.hypot(xScale(d.date) - xm, yScale(d.count) - ym)
        ); // closest point

        servers
          .style("stroke", ([server]) =>
            i.server === server ? null : fadedColor
          )
          .filter(([server]) => i.server === server)
          .raise();
        labels
          .style("fill", (d) => (i.server === d.server ? null : fadedColor))
          .filter((d) => i.server === d.server)
          .raise();
        dot.attr(
          "transform",
          `translate(${xScale(i.date)},${yScale(i.count)})`
        );
        dot.select("text").text(i.count);
        dot.attr("display", null);
      }
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

    // Total population
    // Only display if we have more than one server
    if (L.length > 1) {
      const total_pop = L.reduce((p, c) => {
        return p + c["count"];
      }, 0);

      svg
        .append("text")
        .attr("class", "total_pop")
        .attr("x", xScale(d3.max(X)))
        .attr("dx", 4)
        .attr("y", margin.top)
        .text("Total: " + total_pop);
    }

    setTimeout(nudge, 150);
  };

  const tidy = (data) => {
    return d3.map(data, (d) => {
      return {
        date: d3.utcParse("%Y%m%d")(d.date),
        count: d.count,
        server: d.server,
      };
    });
  };

  /**
   * nudge labels so they don't overlap
   */
  var nudge = function (amount = 5) {
    var maxit = 50;

    var sorted = d3
      .selectAll(".label")
      .sort(function (a, b) {
        return a.count - b.count;
      })
      .nodes();

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
  };

  // Do two SVGRect's intersect?
  // Allows a fudge parameter to allow partial overlap
  var intersects = function (a, b, fudge = 0) {
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
  };

  try {
    d3.json(url)
      .then(tidy)
      .then(draw)
      .catch((err) => {
        console.log(err);
        setStatus(err.response);
      });
  } catch (e) {
    console.log(e);
  }
};
