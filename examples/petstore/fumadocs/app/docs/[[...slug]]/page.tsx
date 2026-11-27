import { source } from '../../../lib/source';
import { DocsPage, DocsBody, DocsTitle, DocsDescription } from 'fumadocs-ui/layouts/docs/page';
import defaultMdxComponents from 'fumadocs-ui/mdx';
import { notFound } from 'next/navigation';
export default async function Page({params}:{params:Promise<{slug?:string[]}>}){
 const page=source.getPage((await params).slug);if(!page)notFound();const MDX=page.data.body;
 return <DocsPage toc={page.data.toc}><DocsTitle>{page.data.title}</DocsTitle><DocsDescription>{page.data.description}</DocsDescription><DocsBody><div data-domstride-guide><MDX components={defaultMdxComponents}/></div></DocsBody></DocsPage>;
}
export function generateStaticParams(){return source.generateParams();}
