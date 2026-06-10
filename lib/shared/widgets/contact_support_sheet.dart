// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Bottom sheet "Contacter le support"
// Charge les contacts depuis l'admin (supportContactsProvider).
// Utilisé par les profils client, pro et livreur.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/support_contacts_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colors.dart';

/// Ouvre la bottom sheet de contact support.
/// [whatsappContext] : texte pré-rempli pour WhatsApp (optionnel).
Future<void> showContactSupportSheet(
  BuildContext context,
  WidgetRef ref, {
  String? whatsappContext,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ContactSupportSheet(
      ref: ref,
      whatsappContext: whatsappContext,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _ContactSupportSheet extends ConsumerWidget {
  final WidgetRef ref;
  final String? whatsappContext;
  const _ContactSupportSheet({required this.ref, this.whatsappContext});

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final contacts = innerRef.watch(supportContactsProvider);

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ─────────────────────────────────────────────────────
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Contacter le support',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Contenu ────────────────────────────────────────────────────
              contacts.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
                error: (_, __) => _FallbackContacts(
                  whatsappContext: whatsappContext,
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return _FallbackContacts(whatsappContext: whatsappContext);
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: list.map((c) {
                      return _ContactTile(
                        contact: c,
                        whatsappContext: whatsappContext,
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final SupportContact contact;
  final String? whatsappContext;
  const _ContactTile({required this.contact, this.whatsappContext});

  @override
  Widget build(BuildContext context) {
    final isWhatsApp = contact.type == 'whatsapp';
    final isEmail    = contact.type == 'email';
    final color = isWhatsApp
        ? const Color(0xFF25D366)
        : isEmail
            ? AppColors.primary
            : AppColors.primary;
    final icon = isWhatsApp
        ? Icons.chat_rounded
        : isEmail
            ? Icons.email_rounded
            : Icons.phone_rounded;

    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        contact.label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
      ),
      subtitle: Text(
        contact.value,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: context.textSecondary,
        ),
      ),
      onTap: () async {
        Navigator.pop(context);
        if (isWhatsApp) {
          await _openWhatsApp(context, contact.cleanPhone, whatsappContext);
        } else if (isEmail) {
          await _openEmail(context, contact.value);
        } else {
          final uri = Uri(scheme: 'tel', path: contact.cleanPhone);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback : si la config admin est vide ou inaccessible, on affiche
// les constantes de AppConstants pour éviter un écran vide.
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackContacts extends StatelessWidget {
  final String? whatsappContext;
  const _FallbackContacts({this.whatsappContext});

  @override
  Widget build(BuildContext context) {
    // Import AppConstants lazily to avoid circular deps
    const fallbackWhatsapp = '22990000000';
    const fallbackEmail    = 'support@ifefood.bj';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chat_rounded,
                color: Color(0xFF25D366), size: 18),
          ),
          title: Text('WhatsApp',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          subtitle: Text('+$fallbackWhatsapp',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: context.textSecondary)),
          onTap: () async {
            Navigator.pop(context);
            await _openWhatsApp(context, fallbackWhatsapp, whatsappContext);
          },
        ),
        ListTile(
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.email_rounded,
                color: AppColors.primary, size: 18),
          ),
          title: Text('Email',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          subtitle: Text(fallbackEmail,
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: context.textSecondary)),
          onTap: () async {
            Navigator.pop(context);
            await _openEmail(context, fallbackEmail);
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

Future<void> _openWhatsApp(
  BuildContext context,
  String phone,
  String? messageContext,
) async {
  final msg = messageContext ?? "Bonjour, j'ai besoin d'aide avec l'app ifè FOOD.";
  final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Impossible d'ouvrir WhatsApp"),
      backgroundColor: AppColors.error,
    ));
  }
}

Future<void> _openEmail(BuildContext context, String email) async {
  final uri = Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: {
      'subject': 'Support ifè FOOD',
      'body': 'Bonjour,\n\nJe vous contacte concernant :\n\n',
    },
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Aucune app email configurée. Écrivez-nous à $email'),
      backgroundColor: AppColors.primary,
    ));
  }
}
