use std::io::{Read, Write};

const PROJECT_NAME: &str = "ynab";
// XXX is this fixed? or is it specific to my account?
const SPLIT_CATEGORY_ID: &str = "4f42d139-ded2-4782-b16e-e944868fbf62";

pub fn api_key() -> std::path::PathBuf {
    directories::ProjectDirs::from("", "", PROJECT_NAME)
        .unwrap()
        .config_dir()
        .join("api-key")
}

pub fn read_api_key() -> String {
    let mut key = String::new();
    let key_file = api_key();
    std::fs::File::open(key_file.clone())
        .unwrap()
        .read_to_string(&mut key)
        .unwrap();
    let key = key.trim();
    key.to_string()
}

#[allow(clippy::cognitive_complexity)]
fn main() {
    let key = read_api_key();
    let mut ynab_config = ynab_api::apis::configuration::Configuration::new();
    ynab_config.api_key = Some(ynab_api::apis::configuration::ApiKey {
        prefix: Some("Bearer".to_string()),
        key: key.to_string(),
    });
    let api = ynab_api::apis::client::APIClient::new(ynab_config);
    let budget_id = api
        .budgets_api()
        .get_budgets()
        .unwrap()
        .data
        .budgets
        .iter()
        .next()
        .unwrap()
        .id
        .clone();
    let budget = api
        .budgets_api()
        .get_budget_by_id(&budget_id, 0)
        .unwrap()
        .data
        .budget;

    let mut file = std::fs::File::create("accounts.tsv").unwrap();
    for account in budget.accounts.unwrap() {
        if account.deleted {
            continue;
        }
        file.write_all(
            [
                account.id.as_ref(),
                account.name.as_ref(),
                if account.on_budget { "1" } else { "0" },
                if account.closed { "1" } else { "0" },
                &format!("{}", account.balance),
                &format!("{}", account.cleared_balance),
                &format!("{}", account.uncleared_balance),
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();

    let mut file = std::fs::File::create("category_groups.tsv").unwrap();
    for category_group in budget.category_groups.unwrap() {
        if category_group.deleted {
            continue;
        }
        file.write_all(
            [
                category_group.id.as_ref(),
                category_group.name.as_ref(),
                if category_group.hidden { "1" } else { "0" },
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();

    let mut file = std::fs::File::create("categories.tsv").unwrap();
    for category in budget.categories.unwrap() {
        if category.deleted {
            continue;
        }
        file.write_all(
            [
                category.id.as_ref(),
                category.category_group_id.as_ref(),
                category.name.as_ref(),
                if category.hidden { "1" } else { "0" },
                &format!("{}", category.budgeted),
                &format!("{}", category.activity),
                &format!("{}", category.balance),
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();

    let mut file = std::fs::File::create("payees.tsv").unwrap();
    for payee in budget.payees.unwrap() {
        if payee.deleted {
            continue;
        }
        let name: &str = payee.name.as_ref();
        file.write_all(
            [
                payee.id.as_ref(),
                name.trim(),
                payee
                    .transfer_account_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();

    let mut file = std::fs::File::create("transactions.tsv").unwrap();
    for transaction in budget.transactions.unwrap() {
        if transaction.deleted {
            continue;
        }
        file.write_all(
            [
                transaction.id.as_ref(),
                transaction.date.as_ref(),
                format!("{}", transaction.amount).as_ref(),
                transaction
                    .memo
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                transaction.cleared.as_ref(),
                if transaction.approved { "1" } else { "0" },
                transaction
                    .flag_color
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                transaction.account_id.as_ref(),
                transaction
                    .payee_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                transaction
                    .category_id
                    .and_then(|id| {
                        // the split category doesn't appear to be in the
                        // categories data, so we have to exclude it or else
                        // the NOT NULL constraint will fail
                        if id == SPLIT_CATEGORY_ID {
                            None
                        } else {
                            Some(id)
                        }
                    })
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                transaction
                    .transfer_account_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();

    let mut file = std::fs::File::create("subtransactions.tsv").unwrap();
    for subtransaction in budget.subtransactions.unwrap() {
        if subtransaction.deleted {
            continue;
        }
        file.write_all(
            [
                subtransaction.id.as_ref(),
                subtransaction.transaction_id.as_ref(),
                format!("{}", subtransaction.amount).as_ref(),
                subtransaction
                    .memo
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                subtransaction
                    .payee_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                subtransaction
                    .category_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                subtransaction
                    .transfer_account_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();

    let mut file = std::fs::File::create("months.tsv").unwrap();
    let mut file2 = std::fs::File::create("categories_by_month.tsv").unwrap();
    for month in budget.months.unwrap() {
        if month.deleted {
            continue;
        }
        file.write_all([month.month.as_ref()].join("\t").as_bytes())
            .unwrap();
        file.write_all(b"\n").unwrap();

        for category in month.categories {
            if category.deleted {
                continue;
            }
            file2
                .write_all(
                    [
                        month.month.as_ref(),
                        category.id.as_ref(),
                        category.category_group_id.as_ref(),
                        category.name.as_ref(),
                        if category.hidden { "1" } else { "0" },
                        &format!("{}", category.budgeted),
                        &format!("{}", category.activity),
                        &format!("{}", category.balance),
                    ]
                    .join("\t")
                    .as_bytes(),
                )
                .unwrap();
            file2.write_all(b"\n").unwrap();
        }
    }
    file.sync_all().unwrap();
    file2.sync_all().unwrap();

    let mut file =
        std::fs::File::create("scheduled_transactions.tsv").unwrap();
    for scheduled_transaction in budget.scheduled_transactions.unwrap() {
        if scheduled_transaction.deleted {
            continue;
        }
        file.write_all(
            [
                scheduled_transaction.id.as_ref(),
                scheduled_transaction.date_next.as_ref(),
                scheduled_transaction.frequency.as_ref(),
                format!("{}", scheduled_transaction.amount).as_ref(),
                scheduled_transaction
                    .memo
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                scheduled_transaction.flag_color.as_ref(),
                scheduled_transaction.account_id.as_ref(),
                scheduled_transaction
                    .payee_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                // the split category doesn't appear to be in the categories
                // data, so we have to exclude it or else the NOT NULL
                // constraint will fail
                if scheduled_transaction.category_id == SPLIT_CATEGORY_ID {
                    "\\N"
                } else {
                    scheduled_transaction.category_id.as_ref()
                },
                scheduled_transaction
                    .transfer_account_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();

    let mut file =
        std::fs::File::create("scheduled_subtransactions.tsv").unwrap();
    for scheduled_subtransaction in budget.scheduled_subtransactions.unwrap()
    {
        if scheduled_subtransaction.deleted {
            continue;
        }
        file.write_all(
            [
                scheduled_subtransaction.id.as_ref(),
                scheduled_subtransaction.scheduled_transaction_id.as_ref(),
                format!("{}", scheduled_subtransaction.amount).as_ref(),
                scheduled_subtransaction
                    .memo
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                scheduled_subtransaction
                    .payee_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
                scheduled_subtransaction.category_id.as_ref(),
                scheduled_subtransaction
                    .transfer_account_id
                    .unwrap_or_else(|| "\\N".to_string())
                    .as_ref(),
            ]
            .join("\t")
            .as_bytes(),
        )
        .unwrap();
        file.write_all(b"\n").unwrap();
    }
    file.sync_all().unwrap();
}
