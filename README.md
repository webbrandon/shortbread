
Shortbread
====

A delicious URL shortener. See it live at http://shrtb.red.

Setup

Shortbread is made with Ruby on Rails.

Install rails:

``` ruby
sudo gem install rails
```

Set up your gems:

``` ruby
bundle install
```

Set up the database:

``` ruby
rake db:migrate
```

This app uses Postgres for the database.

You'll need a domain to point shortened links to. In link.rb, replace `URL_BASE = "shrtb.red/"` with whatever domain you want to serve shortened URLs from.

Shortened URLs are case-sensitive, so bear that in mind.

The site tracks the top 100 most visited links. You can adjust this in the constant `MOST_VISITED_LIMIT` in link.rb.

Test Suite

This app uses Rspec. To run tests on the Link model, simply type:

``` ruby
rspec
```

Building & Pushing Docker Images

To build a container image and push to AWS ECR:
(NOTE: It is assumed docker is logged into AWS ECR)

```bash
git checkout master
make build
make test
make push
```

Deploying to Kubernetes

Namespaces are governed by branch. Only the master branch can be deployed to production and any other branch will be deployed to development. To deploy app to Kubernetes you can run:

```bash
make deploy
```

To run continuous integration on branch run:
```bash
make release
```
