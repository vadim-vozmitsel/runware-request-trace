import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { createClient } from '@runware/sdk'

// Load RUNWARE_API_KEY from .env (next to this file) unless it's already
// set in the environment. An already-exported var always takes precedence.
if (!process.env.RUNWARE_API_KEY) {
  const scriptDir = dirname(fileURLToPath(import.meta.url))
  try {
    const contents = readFileSync(join(scriptDir, '.env'), 'utf8')
    for (const line of contents.split('\n')) {
      const trimmed = line.trim()
      if (!trimmed || trimmed.startsWith('#')) continue
      const eq = trimmed.indexOf('=')
      if (eq === -1) continue
      const key = trimmed.slice(0, eq).trim()
      let value = trimmed.slice(eq + 1).trim()
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1)
      }
      if (key && !(key in process.env)) process.env[key] = value
    }
  } catch {
    // No .env file next to this script; fall through to the check below.
  }
}

const apiKey = process.env.RUNWARE_API_KEY

if (!apiKey) {
  throw new Error(
    'RUNWARE_API_KEY is required. Put it in .env (see .env.example) or export it.',
  )
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
