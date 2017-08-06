library(httr)
library(jsonlite)

endpoint <- "http://localhost:9292"

races <- c(
  "Gharu'ndim",
  "Aluvian",
  "Sho"
)
level_range <- c(1, 275)
servers <- c("Megaduck", "Ducktide", "YewTide", "YewThaw")
nchars <- 20
# From: https://gist.githubusercontent.com/mollietaylor/3837835/raw/d0d2db81b89d29a90fe221542db03a22c5fbf95c/reality.R
first <- c("Fear", "Frontier", "Nanny", "Job", "Yard", "Airport", "Half Pint", "Commando", "Fast Food", "Basketball", "Bachelorette", "Diva", "Baggage", "College", "Octane", "Clean", "Sister", "Army", "Drama", "Backyard", "Pirate", "Shark", "Project", "Model", "Survival", "Justice", "Mom", "New York", "Jersey", "Ax", "Warrior", "Ancient", "Pawn", "Throttle", "The Great American", "Knight", "American", "Outback", "Celebrity", "Air", "Restaurant", "Bachelor", "Family", "Royal", "Surf", "Ulitmate", "Date", "Operation", "Fish Tank", "Logging", "Hollywood", "Amateur", "Craft", "Mystery", "Intervention", "Dog", "Human", "Rock", "Ice Road", "Shipping", "Modern", "Crocodile", "Farm", "Amish", "Single", "Tool", "Boot Camp", "Pioneer", "Kid", "Action", "Bounty", "Paradise", "Mega", "Love", "Style", "Teen", "Pop", "Wedding", "An American", "Treasure", "Myth", "Empire", "Motorway", "Room", "Casino", "Comedy", "Undercover", "Millionaire", "Chopper", "Space", "Cajun", "Hot Rod", "The", "Colonial", "Dance", "Flying", "Sorority", "Mountain", "Auction", "Extreme", "Whale", "Storage", "Cake", "Turf", "UFO", "The Real", "Wild", "Duck", "Queer", "Voice", "Fame", "Music", "Rock Star", "BBQ", "Spouse", "Wife", "Road", "Star", "Renovation", "Comic", "Chef", "Band", "House", "Sweet")
second <- c("Hunters", "Hoarders", "Contest", "Party", "Stars", "Truckers", "Camp", "Dance Crew", "Casting Call", "Inventor", "Search", "Pitmasters", "Blitz", "Marvels", "Wedding", "Crew", "Men", "Project", "Intervention", "Celebrities", "Treasure", "Master", "Days", "Wishes", "Sweets", "Haul", "Hour", "Mania", "Warrior", "Wrangler", "Restoration", "Factor", "Hot Rod", "of Love", "Inventors", "Kitchen", "Casino", "Queens", "Academy", "Superhero", "Battles", "Behavior", "Rules", "Justice", "Date", "Discoveries", "Club", "Brother", "Showdown", "Disasters", "Attack", "Contender", "People", "Raiders", "Story", "Patrol", "House", "Gypsies", "Challenge", "School", "Aliens", "Towers", "Brawlers", "Garage", "Whisperer", "Supermodel", "Boss", "Secrets", "Apprentice", "Icon", "House Party", "Pickers", "Crashers", "Nation", "Files", "Office", "Wars", "Rescue", "VIP", "Fighter", "Job", "Experiment", "Girls", "Quest", "Eats", "Moms", "Idol", "Consignment", "Life", "Dynasty", "Diners", "Chef", "Makeover", "Ninja", "Show", "Ladies", "Dancing", "Greenlight", "Mates", "Wives", "Jail", "Model", "Ship", "Family", "Videos", "Repo", "Rivals", "Room", "Dad", "Star", "Exes", "Island", "Next Door", "Missions", "Kings", "Loser", "Shore", "Assistant", "Comedians", "Rooms", "Boys")

# get two random numbers so we can select the two words:
rand1 <- sample(first, nchars)
rand2 <- sample(second, nchars)
char_names <- paste(rand1, rand2)


for (char_name in char_names) {
  payload <- toJSON(list("server" = sample(servers, 1),
                         "name" = char_name,
                         "level" = runif(1, level_range[1], level_range[2]),
                         "race" = sample(races, 1),
                         "attribs" = list("strength" = 100)
  ), auto_unbox = TRUE)
  POST(endpoint, body = payload)
}
