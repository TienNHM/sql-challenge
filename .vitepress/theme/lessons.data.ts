import { readdirSync, readFileSync } from 'node:fs'
import { join, resolve } from 'node:path'

export interface Lesson {
  day: number
  title: string
  summary: string
  link: string
}

declare const data: Lesson[]
export { data }

const dir = resolve(__dirname, '../../lessons')

export default {
  watch: ['../../lessons/*.md'],
  load(): Lesson[] {
    return readdirSync(dir)
      .filter((f) => f.endsWith('.md'))
      .sort()
      .map((file) => {
        const src = readFileSync(join(dir, file), 'utf8')
        const title = (src.match(/^# (.+)$/m)?.[1] ?? file).replace(/^Ngày \d+: /, '')
        const summary = (src.match(/^> \*\*Tóm tắt:\*\* (.+)$/m)?.[1] ?? '').replace(/`/g, '')
        return { day: Number(file.slice(0, 2)), title, summary, link: `/lessons/${file.replace(/\.md$/, '')}` }
      })
  },
}
