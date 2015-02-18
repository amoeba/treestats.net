# Treestats

Treestats is a player tracking program for [Asheron's Call](http://www.asheronscall.com/) (AC). AC was one of the earliest popular [MMORPG](http://en.wikipedia.org/wiki/Massively_multiplayer_online_role-playing_game) titles and was released in 1999. One of the defining characteristics of AC was its Allegiance system, which allowed players to swear fealty to other players, affording both involved players concrete (e.g. experience and rank for patrons) and social benefits (e.g. items, advice for the vassal).

As vassals gained experience points for themselves, a portion of that experience was passed up to the patron. Players soon manipulated and gamed the system to form efficient experience passup chains and out of this came the original versions of Treestats, written by [Akilla](http://www.akilla.net/).

A long time has passed since Treestats lived I've decided to bring it back as a side project. Much fewer players play the game these days so the purpose of this project is left to the reader.


## What Treestats Does

Treestats records ingame data and stores it in a web-accesible database for convenient browsing. Collected game data include:

- Player metadata, attributes, vitals, and skills
- Allegiance information (Monarchs, patrons, and vassals)
- Server population counts

The web interface also provides extra ways of looking at data, including rankings of attributes, skills, and other statistics.

A novel feature Treestats provides is the viewing of the allegiance tree structure using [D3.js](http://d3js.org):

![Allegiance tree viewer](docs/tree.png)

## Structure

Treestats comes in two parts:

- A [Decal](http://www.decaldev.com/) plugin
- A web app that the Decal plugin communicates with