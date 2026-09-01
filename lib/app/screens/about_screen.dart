import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../models/models.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) vm.backToHome(); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
            onPressed: vm.backToHome,
          ),
          title: Semantics(header: true,
            child: const Text('关于', style: TextStyle(fontWeight: FontWeight.bold))),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: Icon(Icons.search, size: 64,
              color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            const Text('搜索', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('版本 2.0.0', textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280))),
            const Divider(height: 32),
            ListTile(title: const Text('开发者'), subtitle: const Text('白茶不语')),
            ListTile(title: const Text('联系邮箱'),
              subtitle: const Text('baichabuyu8@gmail.com')),
            const Divider(height: 32),
            ListTile(
              title: const Text('检查更新'),
              subtitle: Text(vm.checkingUpdate ? '检查中...' : '点击检查最新版本'),
              trailing: vm.checkingUpdate
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.update),
              onTap: () {
                vm.clearUpdateInfo();
                vm.checkUpdate();
              },
            ),
            // 更新详情
            if (vm.updateInfo != null)
              _UpdateInfoCard(info: vm.updateInfo!),
            ListTile(
              title: const Text('公告'),
              subtitle: Text(vm.announcementLoading ? '加载中...' : '查看最新公告'),
              trailing: vm.announcementLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.notifications),
              onTap: () {
                vm.clearAnnouncement();
                vm.loadAnnouncement();
              },
            ),
            // 公告内容
            if (vm.announcement != null)
              _AnnouncementCard(
                content: vm.announcement!,
                onClose: vm.clearAnnouncement,
              ),
            const Divider(height: 32),
            ListTile(title: const Text('开源声明'),
              onTap: () => _showDialog(context, '开源声明', _licenseText)),
            ListTile(title: const Text('用户协议'),
              onTap: () => _showDialog(context, '用户协议', _agreementText)),
            ListTile(title: const Text('隐私政策'),
              onTap: () => _showDialog(context, '隐私政策', _privacyText)),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, String title, String content) {
    showDialog(context: context,
      // 焦点锁定：只能点"确定"
      barrierDismissible: false,
      builder: (_) =>
      AlertDialog(title: Text(title),
        content: SizedBox(width: 300, child: SingleChildScrollView(
          child: Text(content))),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('确定'))]));
  }
}

class _UpdateInfoCard extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(info.hasUpdate ? '发现新版本' : '当前已是最新版本',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: info.hasUpdate
                        ? Theme.of(context).colorScheme.primary
                        : Colors.green,
                  )),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '关闭',
                  onPressed: () => context.read<SearchViewModel>().clearUpdateInfo(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('版本: ${info.versionName} (${info.versionCode})'),
            const SizedBox(height: 4),
            if (info.updateLog.isNotEmpty)
              Text('更新内容:\n${info.updateLog}'),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String content;
  final VoidCallback onClose;
  const _AnnouncementCard({required this.content, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('公告',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '关闭',
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
  }
}

const _licenseText = '''AnySearch 使用以下开源组件：\n\n- Flutter (BSD-3-Clause)\n- dio (MIT)\n- flutter_markdown (BSD-3-Clause)\n- provider (MIT)\n- url_launcher (BSD-3-Clause)\n- window_manager (MIT)''';

const _agreementText = '''AnySearch 仅为搜索工具，不存储任何内容。\n搜索结果来源于 AnySearch MCP 后端，\n提取的网页内容归原网站所有。\n用户使用本应用即表示同意以上条款。''';

const _privacyText = '''AnySearch 不收集任何个人信息。\n无广告、无追踪 SDK。\n翻译数据发送至腾讯 TranSmart 接口。\n搜索请求发送至 AnySearch MCP 后端。''';