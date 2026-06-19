          if (isAdmin) ...[
            _tile(context, Icons.supervised_user_circle_outlined, '利用者管理', '/settings/members'),
            _tile(context, Icons.vpn_key_outlined, '招待コード', '/settings/invite-codes'),
            const Divider(),
          ],