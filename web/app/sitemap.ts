import type { MetadataRoute } from "next";

const configuredSiteUrl = process.env.NEXT_PUBLIC_SITE_URL?.trim().replace(/\/+$/, "");
const siteUrl = configuredSiteUrl ?? (process.env.NODE_ENV === "development" ? "http://localhost:3000" : undefined);

export default function sitemap(): MetadataRoute.Sitemap {
  if (!siteUrl) {
    return [];
  }

  return [
    {
      url: siteUrl,
      changeFrequency: "monthly",
      priority: 1,
    },
    { url: `${siteUrl}/privacy`, changeFrequency: "yearly", priority: 0.3 },
    { url: `${siteUrl}/terms`, changeFrequency: "yearly", priority: 0.3 },
  ];
}
