# blink2

Ce script ajoute des coffres personnels utilisables avec ox_inventory.

Les coffres acceptent désormais tous les items sans restriction et ne
possèdent pas de limite de poids (capacité à `0`).
Utilisez la commande `/blink` (réservée au blanchisseur) pour créer un point de dépôt à votre position.
Lorsqu'un point est créé, un PNJ aléatoire (issu de la table `blanchiment_ped`)
apparaît à l'endroit choisi.
Approchez-vous de lui et appuyez sur **E** pour ouvrir votre coffre.

La table SQL a été simplifiée et ne contient plus les colonnes `allowed_item`
et `transform_item`.

Commandes admin :
- `/setblanchisseur <id>` ajoute le joueur en tant que blanchisseur
- `/rmblanchisseur <id>` le retire de la liste

