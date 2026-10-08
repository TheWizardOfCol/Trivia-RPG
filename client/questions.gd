extends RefCounted

## Placeholder question data for the first playable battle slice.
## Two banks: the player's starting set and the Bird Scientist's set.
## Replaced by the real question bank (imported from the spreadsheet and
## served by the Elements backend) once that content exists.

const PLAYER_SET := [
	{
		"id": "p1",
		"question": "What is the capital of Australia?",
		"correct": "Canberra",
		"wrong": ["Sydney", "Melbourne", "Perth"],
	},
	{
		"id": "p2",
		"question": "How many continents are there on Earth?",
		"correct": "Seven",
		"wrong": ["Five", "Six", "Eight"],
	},
	{
		"id": "p3",
		"question": "Which planet is closest to the Sun?",
		"correct": "Mercury",
		"wrong": ["Venus", "Mars", "Earth"],
	},
	{
		"id": "p4",
		"question": "What is the largest mammal?",
		"correct": "Blue whale",
		"wrong": ["Elephant", "Giraffe", "Hippopotamus"],
	},
	{
		"id": "p5",
		"question": "How many sides does a hexagon have?",
		"correct": "Six",
		"wrong": ["Five", "Seven", "Eight"],
	},
	{
		"id": "p6",
		"question": "Which element has the symbol O?",
		"correct": "Oxygen",
		"wrong": ["Gold", "Osmium", "Oganesson"],
	},
]

const TRAINER_SET := [
	{
		"id": "t1",
		"question": "Which of these birds cannot fly?",
		"correct": "Penguin",
		"wrong": ["Sparrow", "Crow", "Starling"],
	},
	{
		"id": "t2",
		"question": "What is a group of owls called?",
		"correct": "A parliament",
		"wrong": ["A flock", "A murder", "A gaggle"],
	},
	{
		"id": "t3",
		"question": "Which is the fastest bird in a dive?",
		"correct": "Peregrine falcon",
		"wrong": ["Golden eagle", "Swift", "Albatross"],
	},
	{
		"id": "t4",
		"question": "Which bird lays the largest eggs?",
		"correct": "Ostrich",
		"wrong": ["Emu", "Eagle", "Cassowary"],
	},
	{
		"id": "t5",
		"question": "Do pigeons see more colors than humans?",
		"correct": "Yes, they see more",
		"wrong": ["No, fewer", "Exactly the same", "They are colorblind"],
	},
	{
		"id": "t6",
		"question": "Which bird is a symbol of peace?",
		"correct": "Dove",
		"wrong": ["Raven", "Hawk", "Magpie"],
	},
]

## Returns a shuffled 4-choice array for a question.
static func choices(q: Dictionary) -> Array:
	var c: Array = [q["correct"]]
	c.append_array(q["wrong"])
	c.shuffle()
	return c