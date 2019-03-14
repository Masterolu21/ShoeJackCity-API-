# Sjc 

## Routes
API's root is `/api/v1`.

POST `/users/create_user`, see `SjcWeb.UserController` and `Sjc.Models.User` for required fields needed in the payload.

POST `/users/sign_in`, same as above. This function will return a `JWT` for subsequent calls.

**Following calls require authentication, token on Header**

GET `/users/get_user:id` returns simple data about an user.

POST `/queue/add_player`, after authentication the user will be able to be added to or removed from the `queue`.

## Queue process
`Sjc.Queue`, after starting the process, it'll be populated with 10 games. Each game interval can be configured in the config file for the corresponding environment. Look for the `:game_intervals` key.

when adding a player we need the game the user will be in, for now the games are identified with IDs ranging from 1 to 10. So we do `Sjc.Queue.add_player(2, player)`.

The `player` map should have the ID of the player to add, since we're controlling everything from the same place we get all the information regarding InventoryItems and all that stuff. If the user already exists in the specified game they'll not be added and an error will be returned. If they pick another game they'll be placed into that game instead and removed from the one they were in, if they were in one. Check for the return values on the Queue module.

The IDs for the Queue are configured by default to go from 1 to 10. So, queue with ID 1 being the first one & queue with ID 10 being the last one.

### **NOTE**: In the Queue module we're checking if an user has more than 99 items on their inventory, if they do the user will not be added to the queue. The problem here is that we need to sort of create a temporary inventory for the user so they can pick the items they'll be using in the game, this allows them to have more than 99 items in their inventory and pick the ones they want for the game, we should still remove the items from their inventory after they're used.

You can remove players the same way but calling `Sjc.Queue.remove(game, player_id)`.

Get player's list by calling `Sjc.Queue.players(game)`.

Each second we check for game times to see if one should be started. If a game should start we change its status key on Queue's state, send all the players from the game queue to the Game process and start a game for it.

## Game process
The game process basically takes care of everything related to the logic of the game itself, it can be found at the `Sjc.Game` module.

For the game process you can see the API on the same module. Most of the logic should be done automatically besides adding players, removing players, checking the time left, etc...

Each game is identified by a `name`. Check of modify the Queue module to stick to a naming convention to identify games.

`Sjc.Game.add_action(game_name, action/actions)` (actions can be alist as well)

Actions should follow a format we defined now, not sure if it'll be changed later on. For now actions should be a map as follows:

```elixir
%{
  "from" => user who sent action,
  "type" => "shield" or "bomb",
  "id" => item id
}
```

When adding an action, if the `id` of the user who sent the action is not in the game, we will not add the action to the game, since this is a `.cast` we are not sending a reply back, this will always return `:ok`.

The `"type"` helps us check which actions should take action first, shields are applied first then bombs are executed. If the type is `"shield"` then we target the same user, otherwise we get a random player from the game to apply bomb's damage.

`"amount"` AKA `damage` comes from the item in the database. All items have `damage`, whether they're shields or bombs.

A `round_timeout` message is sent on the process after the specified time has passed. This can be configured on the config file for the environment, look for the `:round_timeout` key.

Once the message is received:

1. The `round_timeout` callback will apply all the shields & bomb's damage as well as removing the used items from their `Sjc.Models.InventoryItems`.
2. After two seconds of all actions applied we send a message for the `standby_phase`, maybe there's more room for something here. This function removes all dead players (Those with less than 0 health points) from the game as well as those with `nil` values in it. In this stage there's also a function call for a 20% chance of the players being revived. Not finished as the Channel room for this wasn't complete. If the players are being removed we should award them some points depending on the number of rounds they lasted.
3. After half a second or a second we send a message again to start the next round. This will clean actions, start a new round timer, put a new round number and remove all shield points from users.