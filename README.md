# memos on fly

[中文说明](https://github.com/ImSingee/memos-on-fly/blob/master/README-cn.md)

> Run the self-hosted memo service [memos](https://github.com/usememos/memos) on [fly.io](https://fly.io/). Automatically backup the database to S3-compatible service with [litestream](https://litestream.io/).

> **Always backup your database. [Read more at fly.io document](https://fly.io/docs/reference/volumes/).**

## Prerequisites

  - [fly.io](https://fly.io/) account
  - [backblaze](https://www.backblaze.com/) account or other S3-compatible service account 

## Install flyctl

1. Follow [the instructions](https://fly.io/docs/getting-started/installing-flyctl/) to install fly's CLI `flyctl`.
2. [log into flyctl](https://fly.io/docs/getting-started/log-in-to-fly/) (`fly auth login`).

## Download the config file

Download [fly.example.toml](https://github.com/ImSingee/memos-on-fly/blob/master/fly.example.toml), put it to an empty directory and rename the file to `fly.toml`.

Inside that direcory, run `fly launch` and answer the questions as following

```
An existing fly.toml file was found for app xxx-memos
? Would you like to copy its configuration to the new app? [Select Yes]

Using build strategies '[the "ghcr.io/imsingee/memos-on-fly:latest" docker image]'. Remove [build] from fly.toml to force a rescan
? Choose an app name (leaving blank will default to 'xxx-memos') [Input your own unique name]

App will use 'hkg' region as primary
Created app 'xxx-memos' in organization 'personal'
Admin URL: https://fly.io/apps/xxx-memos
Hostname: xxx-memos.fly.dev

? Would you like to set up a Postgresql database now? [Select No]

? Would you like to set up an Upstash Redis database now? [Select No]

Wrote config file fly.toml
? Would you like to deploy now? [Select No]

Platform: machines
✓ Configuration is valid
Your app is ready! Deploy with `flyctl deploy`
```

## Prepare the backup service

> If you want to use another storage provider, check litestream's ["Replica Guides"](https://litestream.io/guides/) section and adjust the config as needed.

1. Log into B2 and [create a bucket](https://litestream.io/guides/backblaze/#create-a-bucket). Instead of adjusting the litestream config directly, we will add storage configuration to `fly.toml`. 
2. Now you can set the values of `LITESTREAM_REPLICA_ENDPOINT` and `LITESTREAM_REPLICA_BUCKET` to your `[env]` section.
3. Then, create [an access key](https://litestream.io/guides/backblaze/#create-a-user) for this bucket. Add the key to fly's secret store (Don't add `<` and `>`).
    ```sh
    fly secrets set LITESTREAM_ACCESS_KEY_ID="<keyId>" LITESTREAM_SECRET_ACCESS_KEY="<applicationKey>"
    ```

## Deploy

Run `fly deploy` simply.

If all is well, you can now access memos by running `fly open`. You should see the memoss' login page.

## (Optional) Custom Domains

 Use `fly certs add <your domain>` to configure a custom domain, and follow the instructions to configure the related domain resolution at your DNS service provider (you can check the domain configuration status on the Dashboard Certificate page).

## Other

### How to update to the latest memos release

You can simply re-run the `fly deploy`, and fly.io will pull the latest version and upgrade to it.

> After there's a memos' [offical release](https://github.com/usememos/memos/releases), we will trigger an image build workflow automatically. You can check [here](https://github.com/ImSingee/memos-on-fly/pkgs/container/memos-on-fly) for the exact versions we provide.

### Verify the installation

 - You should be able to log into your memos instance.
 - There should be an initial replica of your database in your B2 bucket.
 - Your user data should survive a restart of the VM.

#### Verify backups / scale persistent volume

Litestream continuously backs up your database by persisting its [WAL](https://en.wikipedia.org/wiki/Write-ahead_logging) to B2, once per second.

There are two ways to verify these backups:

 1. Run the docker image locally or on a second VM. Verify the DB restores correctly.
 2. Swap the fly volume for a new one and verify the DB restores correctly.

We will focus on _2_ as it simulates an actual data loss scenario. This procedure can also be used to scale your volume to a different size.

Start by making a manual backup of your data:

 1. SSH into the VM and copy the DB to a remote. If only you are using your instance, you can also export bookmarks as HTML.
 2. Make a snapshot of the B2 bucket in the B2 admin panel.

Now list all fly volumes and note the id of the `memos_data` volume. Then, delete the volume.

```sh
flyctl volumes list
flyctl volumes delete <id>
```

This will result in a **dead** VM after a few seconds. Create a new `memos_data` volume. Your application should automatically attempt to restart. If not, restart it manually.

When the application starts, you should see the successful restore in the logs.

```
[info] No database found, attempt to restore from a replica.
[info] Finished restoring the database.
[info] Starting litestream & memos service.
```

### Pricing

Assuming one 256MB VM and a 3GB volume, this setup fits within Fly's free tier. [^0] Backups with B2 are free as well. [^1]

[^0]: otherwise the VM is ~$2 per month. $0.15/GB per month for the persistent volume.'
[^1]: the first 10GB are free, then $0.005 per GB.

## Troubleshooting

### litestream is logging 403 errors

Check that your B2 secrets and environment variables are correct.

### fly ssh does not connect

Check the output of `fly doctor`, every line should be marked as **PASSED**. If `Pinging WireGuard` fails, try `fly wireguard reset` and `fly agent restart`.

### fly does not pull in the latest version of memos

Just run `fly deploy --no-cache`

## Thanks to

[hu3rror/memos-on-fly](https://github.com/hu3rror/memos-on-fly)
