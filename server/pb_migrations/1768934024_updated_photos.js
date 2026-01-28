/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_1063624087")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != \"\" && @request.auth.id = owner",
    "deleteRule": "@request.auth.id = owner",
    "listRule": "@request.auth.id != \"\"",
    "updateRule": "@request.auth.id = owner"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_1063624087")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != \"\"",
    "deleteRule": null,
    "listRule": "",
    "updateRule": null
  }, collection)

  return app.save(collection)
})
