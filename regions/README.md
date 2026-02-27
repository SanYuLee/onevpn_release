# Region CIDR data (OneVPN Smart proxy)

Per-country IPv4 CIDR lists for Smart proxy mode: **use_vpn** (only selected regions use VPN) or **not_use_vpn** (selected regions go direct, others use VPN).

## Source

Data is fetched from [ipverse/country-ip-blocks](https://github.com/ipverse/country-ip-blocks):

- ISO 3166-1 alpha-2 country codes
- IPv4 aggregated prefixes from regional internet registries (RIRs)
- Updated daily

URL pattern: `https://raw.githubusercontent.com/ipverse/country-ip-blocks/master/country/<cc>/ipv4-aggregated.txt`  
(use lowercase `<cc>` in the URL; this repo stores files as uppercase `CC.txt`.)

## Format

- One file per region: `CC.txt` (e.g. `US.txt`, `CN.txt`, `JP.txt`).
- Each line: one IPv4 CIDR (e.g. `1.0.0.0/24`).
- Empty lines and lines starting with `#` are ignored.
- Region code in filename is uppercase (e.g. `US`, `GB`).

## Fetching

From the onevpn repo root, run:

```bash
./scripts/fetch-region-cidrs.sh
```

The script reads **`data/regions/country_list.txt`** (one ISO 3166-1 alpha-2 code per line, lowercase). Add or remove lines there and re-run the script to update `CC.txt` files. Build then copies `data/regions/` to the release repo; install scripts deploy it with the client.
