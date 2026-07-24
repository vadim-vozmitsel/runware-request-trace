import { createClient } from '@runware/sdk'

const apiKey = process.env.RUNWARE_API_KEY

if (!apiKey) {
  throw new Error('RUNWARE_API_KEY is required')
}

const client = await createClient({
  apiKey,
  transport: 'rest',
  validate: true,
})

const [image] = await client.run({
  model: 'runware:100@1',
  positivePrompt: 'A lighthouse on a rocky cliff at dusk',
  width: 512,
  height: 512,
  deliveryMethod: 'sync',
  includeCost: true,
})

console.log('sync image', {
  taskUUID: image.taskUUID,
  imageURL: image.imageURL,
  cost: image.cost,
})
