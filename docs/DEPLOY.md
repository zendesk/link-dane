# Deploying Link-Dane

Link-Dane has two major components, a parse.com backend and a static HTML/js/css component.
We've gone with a combination of S3 and [fast.ly](http://www.fastly.com) to serve the static components,
although really any old hosting provider could do.


### How to do it

First, setup your `.env.dev` and `.env.prod` file as described in the 'Secrets' section of SETUP.md.

Make a copy of the `s3.json.example` file (stripping off the `.example`) and replace with your Amazon S3 tokens (use the [`region` found here](https://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region)). This will get you going with the credentials needed to push to S3.

Next, download the parse command line tools as described here: https://parse.com/docs/cloud_code_guide

```
$ curl -s https://www.parse.com/downloads/cloud_code/installer.sh | sudo /bin/bash
```

ensure that you've run grunt -- it will generate the necessary parse configs:

```
$ cd link-dane
$ grunt
```

now make sure that parse is accessible:

```
$ cd server
$ parse list

Associated apps are:
* Link-Dane
  Link-Dane -- Development

```

Finally, deploy away!

```
$ grunt deploy:dev
$ grunt deploy:prod
```
