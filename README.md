# CloudDbUi

A web site for an on-line store.

## Requirements

  - a [postgres:14-alpine](https://hub.docker.com/_/postgres/) 
    data base in a Docker container;
  - a [mayth/simple-upload-server:v1](https://hub.docker.com/r/mayth/simple-upload-server) 
    upload server in an other Docker container.

## Preparations

Configure data base credentials in `/config/dev.exs`.

Create the data base and the necessary tables, then seed the base:

```bash
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

## Running the server

The data base needs to be accessible.

```bash
iex -S mix phx.server
```

## Usage

The web interface is available at [`localhost:4001`](http://localhost:4001).

If the data base has been seeded with `mix run priv/repo/seeds.exs`,
the administrator account is `a@a.pl:Test1234`.

Unregistered guests can only browse `/products`.

Non-administrator users can browse and add orderable `/products` 
to an unpaid order, see their own `/orders`, top up balance at `/top-up`,
and pay for orders.

Administrators can CRUD users, product types, products, orders, 
or order positions (sub-orders).

Some business logic is in place. An incomplete list of examples:

  - administrators cannot top up their balance, order products or pay for
    any orders; 
  - deactivated users cannot log in; 
  - paid orders cannot be deleted (and can be edited only by an 
    administrator); 
  - order positions (sub-orders) of paid orders cannot be edited or deleted; 
  - orders cannot be assigned to administrators, only to non-administrator
    users;
  - deactivated product types cannot be assigned to products;
  - non-orderable products cannot be ordered or assigned to an order 
    position (a sub-order);
  - an order position cannot be assigned to a paid order;
  - a user that has any paid orders or non-zero balance cannot be deleted. 

## TODO:

  * fix tests;
  * hide some UI elements for users/guests;
  * `docker-compose up`;
  * use newer images of PostgreSQL and of the upload server.
