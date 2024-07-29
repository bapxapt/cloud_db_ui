# CloudDbUi

A web site for an on-line store.

## Requirements

  - a running Docker service.

## Preparations

Generate a new secret key base with:

```bash
mix phx.gen.secret
```

Put it into `/docker/.env`.

Set the image server tokens (any string value is valid)
and configure the data base credentials in the same file.

## Running the server

In the root directory of the project:

```bash
cd docker
docker-compose up
```

## Usage

The web interface is available at [`localhost:8080`](http://localhost:8080).

The administrator account is `a@a.pl:Test1234`.

Unregistered guests can only browse orderable `/products`.

Non-administrator users can browse and add orderable `/products` 
to an unpaid order, see their own `/orders`, top up balance at `/top-up`,
and pay for orders.

Administrators can CRUD non-administrator users, product types, products, 
orders, or order positions (sub-orders).

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

Whitespaces in inputs are intentionally left untrimmed. The application
validates input while preserving them.

## TODO:

  * Flop (filtering, sorting, pagination) for `/orders` and for `/sub-orders`;
  * fix query issues at `/orders`;
  * filtering, sorting, pagination tests for `/orders` and for `/sub-orders`;
  * use `Phoenix.PubSub` in some page;
  * hide some UI elements for users/guests.
