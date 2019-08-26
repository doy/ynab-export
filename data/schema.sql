DROP VIEW IF EXISTS denorm_transactions;
DROP VIEW IF EXISTS denorm_scheduled_transactions;
DROP VIEW IF EXISTS future_transactions;
DROP TABLE IF EXISTS ints;
DROP TABLE IF EXISTS scheduled_subtransactions;
DROP TABLE IF EXISTS scheduled_transactions;
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
DROP TYPE IF EXISTS frequency_t;

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
    date date NOT NULL,
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

CREATE TYPE frequency_t AS ENUM (
    'never',
    'daily',
    'weekly',
    'everyOtherWeek',
    'twiceAMonth',
    'every4Weeks',
    'monthly',
    'everyOtherMonth',
    'every3Months',
    'every4Months',
    'twiceAYear',
    'yearly',
    'everyOtherYear'
);
CREATE TABLE scheduled_transactions (
    id text PRIMARY KEY,
    date date NOT NULL,
    frequency frequency_t NOT NULL,
    amount bigint NOT NULL,
    memo text,
    flag_color flag_color_t,
    account_id text REFERENCES accounts(id) NOT NULL,
    payee_id text REFERENCES payees(id),
    category_id text REFERENCES categories(id),
    transfer_account_id text REFERENCES accounts(id)
);

CREATE TABLE scheduled_subtransactions (
    id text PRIMARY KEY,
    scheduled_transaction_id text REFERENCES scheduled_transactions(id) NOT NULL,
    amount bigint NOT NULL,
    memo text,
    payee_id text REFERENCES payees(id),
    category_id text REFERENCES categories(id),
    transfer_account_id text REFERENCES accounts(id)
);

CREATE TABLE ints (
    i integer PRIMARY KEY
);

CREATE VIEW denorm_transactions AS (
    WITH
    transactions_with_subtransactions AS (
        SELECT
            transactions.id,
            subtransactions.id AS subtransaction_id,
            transactions.date,
            coalesce(subtransactions.amount, transactions.amount) AS amount,
            coalesce(subtransactions.memo, transactions.memo) AS memo,
            transactions.cleared,
            transactions.approved,
            transactions.flag_color,
            transactions.account_id,
            coalesce(subtransactions.payee_id, transactions.payee_id) AS payee_id,
            coalesce(subtransactions.category_id, transactions.category_id) AS category_id,
            coalesce(subtransactions.transfer_account_id, transactions.transfer_account_id) AS transfer_account_id
        FROM
            transactions LEFT JOIN subtransactions ON (
                transactions.id = subtransactions.transaction_id
            )
    )
    SELECT
        transactions_with_subtransactions.id,
        subtransaction_id,
        date,
        amount / 1000.0 as amount,
        memo,
        cleared,
        approved,
        flag_color,
        accounts.name AS account,
        payees.name AS payee,
        category_groups.name AS category_group,
        categories.name AS category,
        transfer_accounts.name AS transfer_account
    FROM
        transactions_with_subtransactions LEFT JOIN accounts ON (
            transactions_with_subtransactions.account_id = accounts.id
        ) LEFT JOIN payees ON (
            transactions_with_subtransactions.payee_id = payees.id
        ) LEFT JOIN categories ON (
            transactions_with_subtransactions.category_id = categories.id
        ) LEFT JOIN category_groups ON (
            categories.category_group_id = category_groups.id
        ) LEFT JOIN accounts transfer_accounts ON (
            transactions_with_subtransactions.transfer_account_id = transfer_accounts.id
        )
);

CREATE VIEW denorm_scheduled_transactions AS (
    WITH
    scheduled_transactions_with_subtransactions AS (
        SELECT
            scheduled_transactions.id,
            scheduled_subtransactions.id AS scheduled_subtransaction_id,
            scheduled_transactions.date,
            scheduled_transactions.frequency,
            coalesce(scheduled_subtransactions.amount, scheduled_transactions.amount) AS amount,
            coalesce(scheduled_subtransactions.memo, scheduled_transactions.memo) AS memo,
            scheduled_transactions.flag_color,
            scheduled_transactions.account_id,
            coalesce(scheduled_subtransactions.payee_id, scheduled_transactions.payee_id) AS payee_id,
            coalesce(scheduled_subtransactions.category_id, scheduled_transactions.category_id) AS category_id,
            coalesce(scheduled_subtransactions.transfer_account_id, scheduled_transactions.transfer_account_id) AS transfer_account_id
        FROM
            scheduled_transactions LEFT JOIN scheduled_subtransactions ON (
                scheduled_transactions.id = scheduled_subtransactions.scheduled_transaction_id
            )
    )
    SELECT
        scheduled_transactions_with_subtransactions.id,
        scheduled_subtransaction_id,
        date,
        frequency,
        amount / 1000.0 as amount,
        memo,
        flag_color,
        accounts.name AS account,
        payees.name AS payee,
        category_groups.name AS category_group,
        categories.name AS category,
        transfer_accounts.name AS transfer_account
    FROM
        scheduled_transactions_with_subtransactions LEFT JOIN accounts ON (
            scheduled_transactions_with_subtransactions.account_id = accounts.id
        ) LEFT JOIN payees ON (
            scheduled_transactions_with_subtransactions.payee_id = payees.id
        ) LEFT JOIN categories ON (
            scheduled_transactions_with_subtransactions.category_id = categories.id
        ) LEFT JOIN category_groups ON (
            categories.category_group_id = category_groups.id
        ) LEFT JOIN accounts transfer_accounts ON (
            scheduled_transactions_with_subtransactions.transfer_account_id = transfer_accounts.id
        )
);

CREATE VIEW future_transactions AS (
    WITH
    daily AS (
        SELECT
            'daily'::frequency_t AS frequency,
            (ints.i - 1) * interval '1 day' AS span
        FROM
            ints
        WHERE
            ints.i <= 750
    ),
    weekly AS (
        SELECT
            'weekly'::frequency_t AS frequency,
            (ints.i - 1) * interval '1 week' AS span
        FROM
            ints
        WHERE
            ints.i <= 120
    ),
    every_other_week AS (
        SELECT
            'everyOtherWeek'::frequency_t AS frequency,
            (ints.i - 1) * interval '2 weeks' AS span
        FROM
            ints
        WHERE
            ints.i <= 60
    ),
    twice_a_month AS (
        SELECT
            'twiceAMonth'::frequency_t AS frequency,
            make_interval(months => a.i, days => b.i) AS span
        FROM
            ints a CROSS JOIN ints b
        WHERE
            a.i <= 30 and (b.i = 0 or b.i = 15)
    ),
    every_four_weeks AS (
        SELECT
            'every4Weeks'::frequency_t AS frequency,
            (ints.i - 1) * interval '4 weeks' AS span
        FROM
            ints
        WHERE
            ints.i <= 30
    ),
    monthly AS (
        SELECT
            'monthly'::frequency_t AS frequency,
            (ints.i - 1) * interval '1 month' AS span
        FROM
            ints
        WHERE
            ints.i <= 30
    ),
    every_other_month AS (
        SELECT
            'everyOtherMonth'::frequency_t AS frequency,
            (ints.i - 1) * interval '2 months' AS span
        FROM
            ints
        WHERE
            ints.i <= 15
    ),
    every_three_months AS (
        SELECT
            'every3Months'::frequency_t AS frequency,
            (ints.i - 1) * interval '3 months' AS span
        FROM
            ints
        WHERE
            ints.i <= 10
    ),
    every_four_months AS (
        SELECT
            'every4Months'::frequency_t AS frequency,
            (ints.i - 1) * interval '4 months' AS span
        FROM
            ints
        WHERE
            ints.i <= 10
    ),
    twice_a_year AS (
        SELECT
            'twiceAYear'::frequency_t AS frequency,
            (ints.i - 1) * interval '6 months' AS span
        FROM
            ints
        WHERE
            ints.i <= 5
    ),
    yearly AS (
        SELECT
            'yearly'::frequency_t AS frequency,
            (ints.i - 1) * interval '1 year' AS span
        FROM
            ints
        WHERE
            ints.i <= 5
    ),
    every_other_year AS (
        SELECT
            'everyOtherYear'::frequency_t AS frequency,
            (ints.i - 1) * interval '2 years' AS span
        FROM
            ints
        WHERE
            ints.i <= 5
    ),
    repeated_transactions AS (
        SELECT
            id,
            scheduled_subtransaction_id,
            CASE
            WHEN frequency = 'never' THEN
                date
            WHEN frequency = 'daily' THEN
                date + daily.span
            WHEN frequency = 'weekly' THEN
                date + weekly.span
            WHEN frequency = 'everyOtherWeek' THEN
                date + every_other_week.span
            WHEN frequency = 'twiceAMonth' THEN
                date + twice_a_month.span
            WHEN frequency = 'every4Weeks' THEN
                date + every_four_weeks.span
            WHEN frequency = 'monthly' THEN
                date + monthly.span
            WHEN frequency = 'everyOtherMonth' THEN
                date + every_other_month.span
            WHEN frequency = 'every3Months' THEN
                date + every_three_months.span
            WHEN frequency = 'every4Months' THEN
                date + every_four_months.span
            WHEN frequency = 'twiceAYear' THEN
                date + twice_a_year.span
            WHEN frequency = 'yearly' THEN
                date + yearly.span
            WHEN frequency = 'everyOtherYear' THEN
                date + every_other_year.span
            ELSE
                NULL
            END AS date,
            amount,
            memo,
            flag_color,
            account,
            payee,
            category_group,
            category,
            transfer_account
        FROM
            denorm_scheduled_transactions
                LEFT JOIN daily USING (frequency)
                LEFT JOIN weekly USING (frequency)
                LEFT JOIN every_other_week USING (frequency)
                LEFT JOIN twice_a_month USING (frequency)
                LEFT JOIN every_four_weeks USING (frequency)
                LEFT JOIN monthly USING (frequency)
                LEFT JOIN every_other_month USING (frequency)
                LEFT JOIN every_three_months USING (frequency)
                LEFT JOIN every_four_months USING (frequency)
                LEFT JOIN twice_a_year USING (frequency)
                LEFT JOIN yearly USING (frequency)
                LEFT JOIN every_other_year USING (frequency)
    )
    SELECT
        id,
        scheduled_subtransaction_id,
        date
        amount,
        memo,
        flag_color,
        account,
        payee,
        category_group,
        category,
        transfer_account_id
    FROM
        repeated_transactions
    WHERE
        date <= CURRENT_DATE + interval '2 years'
);
