/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_1063624087")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != \"\"",
    "deleteRule": "owner = @request.auth.id",
    "listRule": "owner = @request.auth.id",
    "updateRule": "owner = @request.auth.id",
    "viewRule": "owner = @request.auth.id"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_1063624087")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != \"\" && @request.auth.id = owner",
    "deleteRule": "@request.auth.id = owner",
    "listRule": "@request.auth.id != \"\"",
    "updateRule": "@request.auth.id = owner",
    "viewRule": "@request.auth.id != \"\""
  }, collection)

  return app.save(collection)
})
