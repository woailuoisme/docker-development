import chalk from 'chalk';

const LEVEL_STYLES = {
  info: tag => chalk.green.bold(tag),
  warn: tag => chalk.yellow.bold(tag),
  error: tag => chalk.red.bold(tag),
  cmd: tag => chalk.cyan.bold(tag),
  event: tag => chalk.magenta.bold(tag),
  init: tag => chalk.bgCyan.black.bold(` ${tag} `)
};

/**
 * 统一控制台日志输出 (带时间戳与色彩标签)
 * @param {'info'|'warn'|'error'|'cmd'|'event'|'init'} level 日志级别
 * @param {string} tag 标签前缀，例如 [INIT], [CONNECT], [TELEMETRY]
 * @param {string} message 日志文本
 */
export function log(level, tag, message) {
  const now = new Date();
  const dateStr = now.toLocaleString('zh-CN', { hour12: false }).replace(/\//g, '-');
  const timestamp = chalk.gray(`[${dateStr}]`);
  const colorizer = LEVEL_STYLES[level] || (t => chalk.white(t));

  console.log(`${timestamp} ${colorizer(tag)} ${message}`);
}
