import 'package:flutter/material.dart';

enum PortalServiceStatus { up, degraded, down, unknown }

class PortalServiceHealth {
  final String name;
  final PortalServiceStatus status;
  final String detail;
  final DateTime? updatedAt;

  const PortalServiceHealth({
    required this.name,
    required this.status,
    required this.detail,
    this.updatedAt,
  });
}

class PortalAuditEvent {
  final DateTime at;
  final String actor;
  final String action;
  final String target;
  final Map<String, String> meta;
  final IconData icon;

  const PortalAuditEvent({
    required this.at,
    required this.actor,
    required this.action,
    required this.target,
    required this.meta,
    required this.icon,
  });
}
