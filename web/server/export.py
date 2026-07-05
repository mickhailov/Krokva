#!/usr/bin/env python3
"""Dump krokva.com subscribers to CSV on stdout."""
import csv
import os
import sqlite3
import sys

DB = os.environ.get("KROKVA_SUB_DB", "/var/lib/krokva-subscribe/subscribers.db")
con = sqlite3.connect(DB)
w = csv.writer(sys.stdout)
w.writerow(["email", "city", "beta", "created_at", "ip", "invited_at"])
for row in con.execute(
    "SELECT email, city, beta, created_at, ip, invited_at FROM subscribers ORDER BY id"
):
    w.writerow(row)
