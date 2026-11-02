import type { Provider } from '@supabase/supabase-js'
import { toErrorMessage } from '~/utils/toErrorMessage'

export type AuthProvider = Extract<Provider, 'google' | 'azure'>

const PROVIDER_OPTIONS: Record<AuthProvider, { scopes?: string, queryParams?: Record<string, string> }> = {
  google: {
    // Always show the account chooser so people can pick another Google account
    queryParams: { prompt: 'select_account' },
  },
  azure: {
    // Supabase requires the `email` scope for Azure; tenant "common" (Hotmail/Outlook/Live
    // + work accounts) is configured in the Supabase dashboard, not here
    scopes: 'email',
    queryParams: { prompt: 'select_account' },
  },
}

/** OAuth sign-in (Google and Microsoft) and sign-out. */
export function useAuth() {
  const supabase = useSupabaseClient()
  const origin = useRequestURL().origin

  const loadingProvider = ref<AuthProvider | null>(null)
  const errorMessage = ref<string | null>(null)

  async function signInWith(provider: AuthProvider): Promise<void> {
    loadingProvider.value = provider
    errorMessage.value = null

    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider,
        options: {
          // Must be listed under Auth > URL Configuration > Redirect URLs in Supabase
          redirectTo: `${origin}/confirm`,
          ...PROVIDER_OPTIONS[provider],
        },
      })
      if (error) throw error
      // On success the browser navigates to the provider, so loading stays on
    }
    catch (error) {
      errorMessage.value = toErrorMessage(error)
      loadingProvider.value = null
    }
  }

  async function signOut(): Promise<void> {
    const { error } = await supabase.auth.signOut()
    if (error) {
      errorMessage.value = toErrorMessage(error)
      return
    }
    useCurrentParticipant().clear()
    await navigateTo('/login')
  }

  return {
    loadingProvider: readonly(loadingProvider),
    errorMessage: readonly(errorMessage),
    signInWithGoogle: () => signInWith('google'),
    signInWithMicrosoft: () => signInWith('azure'),
    signOut,
  }
}
