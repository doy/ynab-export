# ynab-export

This is a simple program to export your YNAB data in CSV form, suitable for
loading directly into a database. The repository includes an example schema
file that can be used to represent this data.

## Example

    ynab-export schema | psql ynab

    ynab-export
    psql ynab -c 'COPY accounts FROM STDIN' < accounts.tsv
    psql ynab -c 'COPY category_groups FROM STDIN' < category_groups.tsv
    psql ynab -c 'COPY categories FROM STDIN' < categories.tsv
    psql ynab -c 'COPY months FROM STDIN' < months.tsv
    psql ynab -c 'COPY categories_by_month FROM STDIN' < categories_by_month.tsv
    psql ynab -c 'COPY payees FROM STDIN' < payees.tsv
    psql ynab -c 'COPY transactions FROM STDIN' < transactions.tsv
    psql ynab -c 'COPY subtransactions FROM STDIN' < subtransactions.tsv
    psql ynab -c 'COPY scheduled_transactions FROM STDIN' < scheduled_transactions.tsv
    psql ynab -c 'COPY scheduled_subtransactions FROM STDIN' < scheduled_subtransactions.tsv
