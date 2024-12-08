
import {
  LandingPage,
  Column,
  Typography,
  ImageSection,
  Box,
  Button,
} from '@oresundsbron/design-system';
import { useTranslation } from 'next-i18next';
import { SEOMetadata } from '../components/SEOMetadata';
import Image from 'next/image';
import { useSEOMetadata } from '../hooks/useSEOMetaData';
import { useLinks } from '../hooks/useLinks';
import { useMemo } from 'react';
import { pipe } from 'fp-ts/lib/function';
import { toUndefined } from 'fp-ts/lib/Option';
import { DefaultLink } from '~/components/Links/DefaultLink';
import { useRouter } from 'next/router';

const arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];


const IMAGE1 = '/images/customer-service.png';

const InternalError = () => {
  const { t } = useTranslation(['error', 'common'], {
    nsMode: 'fallback',
  });

  const { findLinkByCodeRef } = useLinks();
  const customerSupportLink = useMemo(
    () => pipe(findLinkByCodeRef('customer_support'), toUndefined),
    [findLinkByCodeRef]
  );

  const seoMetadata = useSEOMetadata(
    [],
    [
      { name: 'seo-title', content: `${t('internalError.title')}` },
      {
        name: 'seo-description',
        content: `${t('internalError.description')}${t(
          'internalError.homePage'
        )}`,
      },
    ]
  );

  const { locale } = useRouter();
  const generateLink = (locale?: string) => {
    switch (locale) {
      case 'sv':
        return '/sv/kontakta-oss';
      case 'en':
        return '/en/contact-us';
      case 'da':
        return '/da/kontakt-os';
      default:
        return '/contact-us';
    }
  };

  return (
    <>
      <SEOMetadata items={seoMetadata} />
      <LandingPage title="">
        <Column
          as="section"
          column={{ xs: '2/-2', md: '3/-3' }}
          display="flex"
          py="spacing.800"
          sx={{
            justifyContent: 'center',
            flexDirection: 'column',
            textAlign: 'center',
          }}
        >
          <Typography
            variant="h2"
            as="h1"
            sx={{
              fontWeight: 'fontWeights.light',
              lineHeight: 'lineHeights.400',
            }}
          >
            {t('internalError.title')}
          </Typography>
          <Typography>
            {t('internalError.description')}
            <DefaultLink href={generateLink(locale)} color={'default'}>
              {t('internalError.homePage')}
            </DefaultLink>
          </Typography>
        </Column>
        <Column column="1/-1" as="section">
          <ImageSection
            image={
              <Image
                alt="IMAGE1"
                src={IMAGE1}
                sizes="(max-width: 768px) 50vw,
                (max-width: 1200px) 25vw,
                25vw"
                fill
                style={{
                  aspectRatio: '16/9',
                  objectFit: 'cover',
                }}
                unoptimized
              />
            }
          >
            <Box
              display="flex"
              py="spacing.800"
              sx={{
                flexDirection: 'column',
                justifyContent: 'center',
                alignItems: 'center',
                backgroundColor: 'colors.primary.600',
              }}
            >
              <Box
                sx={{ maxWidth: '65ch', px: 'spacing.500', pb: 'spacing.400' }}
              >
                <Typography variant="h3" sx={{ color: 'colors.white' }}>
                  {t('customerSupport.title')}
                </Typography>
                <Typography
                  variant="paragraph"
                  sx={{ py: 'spacing.400', color: 'colors.white' }}
                >
                  {t('customerSupport.description')}
                </Typography>
                <Button
                  as={DefaultLink}
                  href={customerSupportLink?.path}
                  variant="outlined"
                  mt="spacing.400"
                  sx={{
                    color: 'colors.white',
                    borderColor: 'colors.white',
                    width: 'fit-content',
                  }}
                >
                  {t('customerSupport.button')}
                </Button>
              </Box>
            </Box>
          </ImageSection>
        </Column>
      </LandingPage>
    </>
  );
};

export default InternalError;
