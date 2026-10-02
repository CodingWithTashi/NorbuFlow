# Registering a temple

Three requests, sent from a terminal. The app cannot make them: each needs the
operator's key, `ADMIN_KEY` in `functions/.env`.

What to ask the temple for: its **name**, a **line describing it**, its
**logo** as an image file, and the **email of the person who will run it**.

## Before the first time

```sh
# Git Bash. Copy the value of ADMIN_KEY from functions/.env.
export NORBU_KEY='paste the key here'
export NORBU_API='https://us-central1-norbu-flow.cloudfunctions.net'
```

PowerShell: `$env:NORBU_KEY = '...'`, and use `$env:NORBU_KEY` and
`$env:NORBU_API` in place of `$NORBU_KEY` and `$NORBU_API` below (with
`curl.exe` instead of `curl`).

Against the local emulator (`npm run serve`), the address is
`http://127.0.0.1:5001/norbu-flow/us-central1`.

## 1. Create the temple

```sh
curl -X POST "$NORBU_API/temples-create" \
  -H "Authorization: Bearer $NORBU_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Drolma Ling Centre",
    "description": "Kagyu tradition · Vancouver",
    "timeZone": "America/Vancouver"
  }'
```

```json
{
  "temple": {
    "id": "drolma-ling-centre",
    "name": "Drolma Ling Centre",
    "description": "Kagyu tradition · Vancouver",
    "timeZone": "America/Vancouver",
    "cardTemplate": "standard",
    "membership": { "kind": "rolling", "months": 12 },
    "hasLogo": false
  }
}
```

Keep the `id`: the next two requests need it. It is made from the name. Sent
twice, the second request is refused (`409`), so a temple is never registered
twice by accident.

Only `name` and `timeZone` must be sent. The rest, with what is used when it
is left out:

| Field          | Left out                                | Example                                                        |
| -------------- | --------------------------------------- | -------------------------------------------------------------- |
| `id`           | made from the name                      | `"drolma-ling-vancouver"`                                      |
| `description`  | empty                                   | `"Kagyu tradition · Vancouver"`                                |
| `membership`   | twelve months from the day it is bought | `{ "kind": "fixedYearEnd", "month": 7, "day": 31 }`            |
| `memberNumber` | starts at 1, written as it is           | `{ "next": 142, "prefix": "DL-", "minDigits": 4 }` → `DL-0142` |
| `cardTemplate` | `standard`                              | `"drepung-loseling-canada"`                                    |

`timeZone` is an IANA name: `America/Toronto`, `America/Vancouver`,
`America/New_York`, `Asia/Kolkata`, `Asia/Kathmandu`, `Asia/Taipei`,
`Europe/Paris`, `Europe/Zurich`, `Europe/London`, `Australia/Sydney`.

The standard card prints the temple's name in Latin letters, on at most two
lines. A name it cannot print is refused (`400`), saying so.

## 2. Upload the logo

```sh
curl -X POST "$NORBU_API/temples-setLogo?templeId=drolma-ling-centre" \
  -H "Authorization: Bearer $NORBU_KEY" \
  -H "Content-Type: image/png" \
  --data-binary @logo.png
```

A PNG or a JPEG, up to 5 MB. Square works best: it is shown round in the app
and on the standard card. Send it again to replace it.

```json
{ "temple": { "id": "drolma-ling-centre", "hasLogo": true, "...": "..." } }
```

## 3. Assign the temple to its admin

```sh
curl -X POST "$NORBU_API/temples-addAdmin" \
  -H "Authorization: Bearer $NORBU_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "templeId": "drolma-ling-centre", "email": "lama.karma@drolmaling.ca" }'
```

```json
{
  "temple": { "id": "drolma-ling-centre", "...": "..." },
  "email": "lama.karma@drolmaling.ca",
  "role": "admin"
}
```

This puts the email on the temple's team as its admin and gives it an account
in Firebase Authentication. **Nothing is emailed.** Tell them to install the
app, type this email, and tap "Email me a sign-in link"; the link arrives from
Firebase. They sign in the same way after signing out.

An email that was never added is told so on the app's sign-in screen, and is
sent no link.

Send the request again with another email to give the temple a second admin,
or with another `templeId` to give one person a second temple.

## When a request is refused

```json
{
  "error": {
    "kind": "invalid",
    "message": "...",
    "fields": { "timeZone": "Not an IANA time zone. Try America/Toronto." }
  }
}
```

| Status | Meaning                                                      |
| ------ | ------------------------------------------------------------ |
| `400`  | Something sent cannot be used. `fields` says what, in words. |
| `401`  | The key is missing or wrong.                                 |
| `404`  | No temple has that id.                                       |
| `409`  | A temple already has that id. Send another `"id"`.           |
| `500`  | Something broke. `npm run logs` says what.                   |

## Other roles

Staff other than admins are still added from a terminal:

```sh
npm run db:staff -- <temple-id> <email> <role>
```
