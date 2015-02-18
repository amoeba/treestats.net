TODO
====

Web App
-------

### General

- Remove x axis label, move y axis label to top so there's less blank space
- Design and add favicon

### Player Counts

- Try a new serverpop chart tooltip idea. Add no-fill, no -stroke circles at the nodes but have them light up when you hover. Have *those* handle the tooltips instead of the paths.
- Consider using delayed job to generate daily charts
- Also consider calculating no more than one value per day, or use a box-whisker or something
- Fix rake error on deploy


Decal Plugin
------------

- Generate a VVS view
- Consider opt-in or opt-out tracking
- Add whitelisting feature, UI plus CLI?