# LIGO Deku RPC

RPC server for compiling LIGO code to Deku-compatible WASM.

## Endpoints

- POST: /api/v1/ligo/originate
  - Body: `{ "lang": <supported ligo syntax>, "source": "<LIGO source>", "storage": "<initial storage>"}`
  - Returns: String with `.wat` formatted code
