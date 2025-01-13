DROP VIEW IF EXISTS future_transactions;
DROP VIEW IF EXISTS denorm_scheduled_transactions;
DROP VIEW IF EXISTS denorm_transactions;
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

CREATE TABLE transactions (
    id text PRIMARY KEY,
    date date NOT NULL,
    amount bigint NOT NULL,
    memo text,
    cleared text NOT NULL,
    approved boolean NOT NULL,
    flag_color text,
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

CREATE TABLE scheduled_transactions (
    id text PRIMARY KEY,
    date date NOT NULL,
    frequency text NOT NULL,
    amount bigint NOT NULL,
    memo text,
    flag_color text,
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

CREATE VIEW denorm_transactions AS
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
        account_id,
        accounts.name AS account,
        payee_id,
        payees.name AS payee,
        category_group_id,
        category_groups.name AS category_group,
        category_id,
        categories.name AS category,
        transactions_with_subtransactions.transfer_account_id,
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
        );

CREATE VIEW denorm_scheduled_transactions AS
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
        account_id,
        accounts.name AS account,
        payee_id,
        payees.name AS payee,
        category_group_id,
        category_groups.name AS category_group,
        category_id,
        categories.name AS category,
        scheduled_transactions_with_subtransactions.transfer_account_id,
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
        );

CREATE VIEW future_transactions AS
    WITH
    daily AS (
        SELECT
            'daily' AS frequency,
            (ints.i - 1) AS days
        FROM
            ints
        WHERE
            ints.i <= 750
    ),
    weekly AS (
        SELECT
            'weekly' AS frequency,
            (ints.i - 1) * 7 AS days
        FROM
            ints
        WHERE
            ints.i <= 120
    ),
    every_other_week AS (
        SELECT
            'everyOtherWeek' AS frequency,
            (ints.i - 1) * 14 AS days
        FROM
            ints
        WHERE
            ints.i <= 60
    ),
    twice_a_month AS (
        SELECT
            'twiceAMonth' AS frequency,
            a.i AS months,
            b.i AS days
        FROM
            ints a CROSS JOIN ints b
        WHERE
            a.i <= 30 and (b.i = 0 or b.i = 15)
    ),
    every_four_weeks AS (
        SELECT
            'every4Weeks' AS frequency,
            (ints.i - 1) * 28 AS days
        FROM
            ints
        WHERE
            ints.i <= 30
    ),
    monthly AS (
        SELECT
            'monthly' AS frequency,
            (ints.i - 1) AS months
        FROM
            ints
        WHERE
            ints.i <= 30
    ),
    every_other_month AS (
        SELECT
            'everyOtherMonth' AS frequency,
            (ints.i - 1) * 2 AS months
        FROM
            ints
        WHERE
            ints.i <= 15
    ),
    every_three_months AS (
        SELECT
            'every3Months' AS frequency,
            (ints.i - 1) * 3 AS months
        FROM
            ints
        WHERE
            ints.i <= 10
    ),
    every_four_months AS (
        SELECT
            'every4Months' AS frequency,
            (ints.i - 1) * 4 AS months
        FROM
            ints
        WHERE
            ints.i <= 10
    ),
    twice_a_year AS (
        SELECT
            'twiceAYear' AS frequency,
            (ints.i - 1) * 6 AS months
        FROM
            ints
        WHERE
            ints.i <= 5
    ),
    yearly AS (
        SELECT
            'yearly' AS frequency,
            (ints.i - 1) * 12 AS months
        FROM
            ints
        WHERE
            ints.i <= 5
    ),
    every_other_year AS (
        SELECT
            'everyOtherYear' AS frequency,
            (ints.i - 1) * 24 AS months
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
                datetime(date)
            WHEN frequency = 'daily' THEN
                datetime(date, '+' || daily.days || ' days')
            WHEN frequency = 'weekly' THEN
                datetime(date, '+' || weekly.days || ' days')
            WHEN frequency = 'everyOtherWeek' THEN
                datetime(date, '+' || every_other_week.days || ' days')
            WHEN frequency = 'twiceAMonth' THEN
                datetime(date, '+' || twice_a_month.days || ' days', '+' || twice_a_month.months || ' months')
            WHEN frequency = 'every4Weeks' THEN
                datetime(date, '+' || every_four_weeks.days || ' days')
            WHEN frequency = 'monthly' THEN
                datetime(date, '+' || monthly.months || ' months')
            WHEN frequency = 'everyOtherMonth' THEN
                datetime(date, '+' || every_other_month.months || ' months')
            WHEN frequency = 'every3Months' THEN
                datetime(date, '+' || every_three_months.months || ' months')
            WHEN frequency = 'every4Months' THEN
                datetime(date, '+' || every_four_months.months || ' months')
            WHEN frequency = 'twiceAYear' THEN
                datetime(date, '+' || twice_a_year.months || ' months')
            WHEN frequency = 'yearly' THEN
                datetime(date, '+' || yearly.months || ' months')
            WHEN frequency = 'everyOtherYear' THEN
                datetime(date, '+' || every_other_year.months || ' months')
            ELSE
                NULL
            END AS date,
            frequency,
            amount,
            memo,
            flag_color,
            account_id,
            account,
            payee_id,
            payee,
            category_group_id,
            category_group,
            category_id,
            category,
            transfer_account_id,
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
        date,
        frequency,
        amount,
        memo,
        flag_color,
        account_id,
        account,
        payee_id,
        payee,
        category_group_id,
        category_group,
        category_id,
        category,
        transfer_account_id,
        transfer_account
    FROM
        repeated_transactions
    WHERE
        date <= date('now', '+2 years');
