# blink2

Ce script ajoute des coffres personnels utilisables avec ox_inventory.

Les coffres acceptent uniquement l'item `black_money`. Celui-ci est
automatiquement converti en `money` au rythme d'une unité toutes les deux
secondes.
Utilisez la commande `/blink` pour créer un point de dépôt à votre position.
Lorsqu'un point est créé, un PNJ "u_m_y_smugmech_01" apparaît à l'endroit choisi.
Approchez-vous de lui et appuyez sur **E** pour ouvrir votre coffre.

La table SQL comporte désormais deux colonnes `allowed_item` et
`transform_item` qui définissent respectivement l'objet accepté et celui généré
par le processus de blanchiment.
