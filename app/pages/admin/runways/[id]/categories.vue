<script setup lang="ts">
import type { AdminCategory } from '~/composables/useAdminRunway'
import type { Enums } from '~/types/database.types'

type CategoryKind = Enums<'category_kind'>

const supabase = useSupabaseClient()
const { runway, categories, refresh } = useAdminRunway()
const { listCategoryFiles, removeFiles } = useParticipantFiles()

// --- Edit title / intro, delete ----------------------------------------------
const categoryDrafts = reactive<Record<string, { title: string, intro: string, kind: CategoryKind }>>({})
watch(categories, (list) => {
  for (const category of list) {
    categoryDrafts[category.id] ??= { title: category.title, intro: category.intro_text ?? '', kind: category.kind }
  }
}, { immediate: true })

const categorySavingId = ref<string | null>(null)
const categoryErrors = reactive<Record<string, string>>({})

const categoryChanged = (category: AdminCategory): boolean => {
  const draft = categoryDrafts[category.id]
  return !!draft && (draft.title.trim() !== category.title || (draft.intro.trim() || null) !== category.intro_text || draft.kind !== category.kind)
}

async function saveCategory(category: AdminCategory): Promise<void> {
  const draft = categoryDrafts[category.id]
  if (!draft || !categoryChanged(category) || !draft.title.trim() || categorySavingId.value) return

  categorySavingId.value = category.id
  delete categoryErrors[category.id]
  try {
    const { error } = await supabase
      .from('categories')
      .update({ title: draft.title.trim(), intro_text: draft.intro.trim() || null, kind: draft.kind })
      .eq('id', category.id)
    if (error) throw error
    await refresh()
  }
  catch (error) {
    categoryErrors[category.id] = toErrorMessage(error)
  }
  finally {
    categorySavingId.value = null
  }
}

async function deleteCategory(category: AdminCategory): Promise<void> {
  if (categorySavingId.value) return
  if (!window.confirm(`¿Eliminar la categoría «${category.title}»? También se borrarán sus looks.`)) return

  categorySavingId.value = category.id
  delete categoryErrors[category.id]
  try {
    // The looks cascade with the row; list their files first so they can be removed from Storage
    const files = await listCategoryFiles(category.id)
    const { error } = await supabase.from('categories').delete().eq('id', category.id)
    if (error) throw error
    await removeFiles(files)
    await refresh()
  }
  catch (error) {
    categoryErrors[category.id] = toErrorMessage(error)
  }
  finally {
    categorySavingId.value = null
  }
}

// --- New category --------------------------------------------------------------
const newCategoryOpen = ref(false)
const newTitle = ref('')
const newIntro = ref('')
const newKind = ref<CategoryKind>('individual')
const newCategorySaving = ref(false)
const newCategoryError = ref<string | null>(null)

function openNewCategory(): void {
  newTitle.value = ''
  newIntro.value = ''
  newKind.value = 'individual'
  newCategoryError.value = null
  newCategoryOpen.value = true
}

async function createCategory(): Promise<void> {
  if (!newTitle.value.trim() || newCategorySaving.value) return

  newCategorySaving.value = true
  newCategoryError.value = null
  try {
    const { error } = await supabase
      .from('categories')
      .insert({ runway_id: runway.value.id, title: newTitle.value.trim(), intro_text: newIntro.value.trim() || null, kind: newKind.value })
    if (error) throw error
    newCategoryOpen.value = false
    await refresh()
  }
  catch (error) {
    newCategoryError.value = toErrorMessage(error)
  }
  finally {
    newCategorySaving.value = false
  }
}
</script>

<template>
  <section class="section" aria-labelledby="categories-title">
    <div class="section-header">
      <h2 id="categories-title">
        Categorías
      </h2>
      <button type="button" class="btn btn--primary" @click="openNewCategory">
        + Nueva categoría
      </button>
    </div>

    <p v-if="!categories.length" class="empty">
      Añade al menos una categoría para poder subir los looks.
    </p>

    <template v-for="category in categories" :key="category.id">
    <form
      class="card form"
      @submit.prevent="saveCategory(category)"
    >
      <div class="field">
        <label :for="`category-title-${category.id}`" class="field__label">Título</label>
        <input
          :id="`category-title-${category.id}`"
          v-model="categoryDrafts[category.id]!.title"
          class="field__input"
          type="text"
          maxlength="100"
          required
        >
      </div>
      <div class="field">
        <label :for="`category-intro-${category.id}`" class="field__label">Introducción</label>
        <textarea
          :id="`category-intro-${category.id}`"
          v-model="categoryDrafts[category.id]!.intro"
          class="field__input"
          rows="3"
        />
      </div>
      <div class="field">
        <label :for="`category-kind-${category.id}`" class="field__label">Tipo</label>
        <select :id="`category-kind-${category.id}`" v-model="categoryDrafts[category.id]!.kind" class="field__input">
          <option value="individual">
            Individual
          </option>
          <option value="group">
            Grupal (dos grupos)
          </option>
        </select>
      </div>
      <p v-if="categoryErrors[category.id]" class="form-error" role="alert">
        {{ categoryErrors[category.id] }}
      </p>
      <div class="form-actions">
        <button
          v-if="canEditLooks(runway.status)"
          type="button"
          class="btn btn--ghost"
          :disabled="categorySavingId !== null"
          @click="deleteCategory(category)"
        >
          Eliminar
        </button>
        <button type="submit" class="btn btn--primary" :disabled="!categoryChanged(category) || categorySavingId !== null">
          {{ categorySavingId === category.id ? 'Guardando…' : 'Guardar' }}
        </button>
      </div>
    </form>
    <AdminCategoryGroups v-if="category.kind === 'group'" :category-id="category.id" />
    </template>
  </section>

  <AppModal :open="newCategoryOpen" title="Nueva categoría" @close="newCategoryOpen = false">
    <form class="form" @submit.prevent="createCategory">
      <div class="field">
        <label for="new-category-title" class="field__label">Título</label>
        <input
          id="new-category-title"
          v-model="newTitle"
          class="field__input"
          type="text"
          maxlength="100"
          required
          placeholder="Ej. Alta costura espacial"
        >
      </div>
      <div class="field">
        <label for="new-category-intro" class="field__label">Introducción</label>
        <textarea
          id="new-category-intro"
          v-model="newIntro"
          class="field__input"
          rows="3"
          placeholder="Describe el tema (opcional)"
        />
      </div>
      <div class="field">
        <label for="new-category-kind" class="field__label">Tipo</label>
        <select id="new-category-kind" v-model="newKind" class="field__input">
          <option value="individual">
            Individual
          </option>
          <option value="group">
            Grupal (dos grupos)
          </option>
        </select>
      </div>
      <p v-if="newCategoryError" class="form-error" role="alert">
        {{ newCategoryError }}
      </p>
      <div class="form-actions">
        <button type="button" class="btn btn--ghost" @click="newCategoryOpen = false">
          Cancelar
        </button>
        <button type="submit" class="btn btn--primary" :disabled="!newTitle.trim() || newCategorySaving">
          {{ newCategorySaving ? 'Creando…' : 'Crear categoría' }}
        </button>
      </div>
    </form>
  </AppModal>
</template>
