import 'package:flutter/material.dart';

typedef AdminResourceDefinition = ({
  String label,
  String description,
  IconData icon,
});

const adminResources = <String, AdminResourceDefinition>{
  'users': (
    label: 'Users',
    description: 'Profiles, access, roles and account status',
    icon: Icons.people_outline_rounded,
  ),
  'wagers': (
    label: 'Wagers',
    description: 'Create wagers and manage their lifecycle',
    icon: Icons.emoji_events_outlined,
  ),
  'payments': (
    label: 'Payments',
    description: 'Inspect and safely re-verify provider payments',
    icon: Icons.payments_outlined,
  ),
  'wallets': (
    label: 'Wallets',
    description: 'Balances and audited manual adjustments',
    icon: Icons.account_balance_wallet_outlined,
  ),
  'transactions': (
    label: 'Transactions',
    description: 'Immutable platform-wide ledger activity',
    icon: Icons.receipt_long_outlined,
  ),
  'settings': (
    label: 'System settings',
    description: 'Create and update runtime configuration values',
    icon: Icons.tune_rounded,
  ),
};
