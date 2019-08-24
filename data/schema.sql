DROP TABLE IF EXISTS subtransactions;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS payees;
DROP TABLE IF EXISTS categories_by_month;
DROP TABLE IF EXISTS months;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS category_groups;
DROP TABLE IF EXISTS accounts;
DROP TYPE IF EXISTS cleared_t;
DROP TYPE IF EXISTS flag_color_t;

CREATE TABLE accounts (
    id text PRIMARY KEY,
    name text NOT NULL,
    on_budget boolean NOT NULL,
    closed boolean NOT NULL,
    balance bigint NOT NULL,
    cleared_balance bigint NOT NULL,
    uncleared_balance bigint NOT NULL
);

CREATE TABLE category_groups (
    id text PRIMARY KEY,
    name text NOT NULL,
    hidden boolean NOT NULL
);

CREATE TABLE categories (
    id text PRIMARY KEY,
    category_group_id text REFERENCES category_groups(id) NOT NULL,
    name text NOT NULL,
    hidden boolean NOT NULL,
    budgeted bigint NOT NULL,
    activity bigint NOT NULL,
    balance bigint NOT NULL
);

CREATE TABLE months (
    month date PRIMARY KEY
);

CREATE TABLE categories_by_month (
    month date REFERENCES months(month),
    id text REFERENCES categories(id),
    category_group_id text REFERENCES category_groups(id) NOT NULL,
    name text NOT NULL,
    hidden boolean NOT NULL,
    budgeted bigint NOT NULL,
    activity bigint NOT NULL,
    balance bigint NOT NULL,
    PRIMARY KEY (month, id)
);

CREATE TABLE payees (
    id text PRIMARY KEY,
    name text NOT NULL,
    transfer_account_id text REFERENCES accounts(id)
);

CREATE TYPE cleared_t AS ENUM ('reconciled', 'cleared', 'uncleared');
CREATE TYPE flag_color_t AS ENUM('red', 'orange', 'yellow', 'green', 'blue', 'purple');

CREATE TABLE transactions (
    id text PRIMARY KEY,
    transaction_date date NOT NULL,
    amount bigint NOT NULL,
    memo text,
    cleared cleared_t NOT NULL,
    approved boolean NOT NULL,
    flag_color flag_color_t,
    account_id text REFERENCES accounts(id) NOT NULL,
    payee_id text REFERENCES payees(id),
    category_id text REFERENCES categories(id),
    transfer_account_id text REFERENCES accounts(id)
);

CREATE TABLE subtransactions (
    id text PRIMARY KEY,
    transaction_id text REFERENCES transactions(id) NOT NULL,
    amount bigint NOT NULL,
    memo text,
    payee_id text REFERENCES payees(id),
    category_id text REFERENCES categories(id),
    transfer_account_id text REFERENCES accounts(id)
);
