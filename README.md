# liar's-deck-TASM
Liar's Deck game Turbo Assembly version

Game Rule:
Deck Contains total of 20 cards:
- 6 Kings
- 6 Queens
- 6 Aces
- 2 Joker

Each player is dealed 5 cards from the shuffled deck
Player can select up to 3 cards from their hand to play
After a player played their cards, the opposite player can either accept or call liar

Played cards will be revealed when a player is accused of lying
If accused player found lying (played cards not same type as table type), they will face a Russian Roulette
If accuser is false they will face the roulette instead

After every event of Russian roulette, move to new round and players are dealed with new hand
Game end when 1 of the player dies from Russian Roulette
