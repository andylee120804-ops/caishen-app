import { DeityInfo, FIVE_DEITIES } from '../model/PrayerTypes'

export class DeityRotator {
  private static computeDeityId(date: Date): number {
    const startOfYear = new Date(date.getFullYear(), 0, 1)
    const dayOfYear = Math.floor(
      (date.getTime() - startOfYear.getTime()) / (1000 * 60 * 60 * 24)
    ) + 1
    return ((dayOfYear - 1) % 5) + 1
  }

  /**
   * 主位轮转映射（对调方案）：锚点编号 == 神 id 方位序（1中/2东/3西/4南/5北）。
   * 今日主神站中央主位（锚点1），中路财神（id1）暂代主神原方位锚点，其余三路财神守本方位。
   * 纯函数：同一天结果恒定（当天固定），跨天随 todayId 变化（轮换）。
   */
  static anchorOf(deityId: number, todayId: number): number {
    if (deityId === todayId) return 1
    if (deityId === 1) return todayId
    return deityId
  }

  static getTodayDeity(): DeityInfo {
    const deityId = DeityRotator.computeDeityId(new Date())
    const deity = FIVE_DEITIES.find(d => d.id === deityId)
    if (!deity) {
      return FIVE_DEITIES[0] // fallback to first deity
    }
    return deity
  }

  static getDeityByDate(dateStr: string): DeityInfo {
    const d = new Date(dateStr)
    if (isNaN(d.getTime())) {
      return FIVE_DEITIES[0] // invalid date fallback
    }
    const deityId = DeityRotator.computeDeityId(d)
    const deity = FIVE_DEITIES.find(d => d.id === deityId)
    if (!deity) {
      return FIVE_DEITIES[0]
    }
    return deity
  }

  static getAllDeities(): DeityInfo[] {
    return FIVE_DEITIES
  }
}