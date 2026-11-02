// Mirrors the output of `supabase gen types typescript` for the current migrations.
// Regenerate after schema changes:
//   npx supabase gen types typescript --linked > app/types/database.types.ts

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      categories: {
        Row: {
          created_at: string
          id: string
          intro_text: string | null
          status: Database['public']['Enums']['category_status']
          title: string
          updated_at: string
          week_number: number
        }
        Insert: {
          created_at?: string
          id?: string
          intro_text?: string | null
          status?: Database['public']['Enums']['category_status']
          title: string
          updated_at?: string
          week_number: number
        }
        Update: {
          created_at?: string
          id?: string
          intro_text?: string | null
          status?: Database['public']['Enums']['category_status']
          title?: string
          updated_at?: string
          week_number?: number
        }
        Relationships: []
      }
      looks: {
        Row: {
          category_id: string
          created_at: string
          id: string
          image_url: string
          intro: string | null
          participant_id: string
          updated_at: string
          uploaded_by: string | null
        }
        Insert: {
          category_id: string
          created_at?: string
          id?: string
          image_url: string
          intro?: string | null
          participant_id: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Update: {
          category_id?: string
          created_at?: string
          id?: string
          image_url?: string
          intro?: string | null
          participant_id?: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: 'looks_category_id_fkey'
            columns: ['category_id']
            isOneToOne: false
            referencedRelation: 'categories'
            referencedColumns: ['id']
          },
          {
            foreignKeyName: 'looks_participant_id_fkey'
            columns: ['participant_id']
            isOneToOne: false
            referencedRelation: 'participants'
            referencedColumns: ['id']
          },
          {
            foreignKeyName: 'looks_uploaded_by_fkey'
            columns: ['uploaded_by']
            isOneToOne: false
            referencedRelation: 'participants'
            referencedColumns: ['id']
          },
        ]
      }
      participants: {
        Row: {
          created_at: string
          drag_name: string | null
          email: string
          id: string
          name: string
          role: Database['public']['Enums']['participant_role']
          updated_at: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          drag_name?: string | null
          email: string
          id?: string
          name: string
          role?: Database['public']['Enums']['participant_role']
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          drag_name?: string | null
          email?: string
          id?: string
          name?: string
          role?: Database['public']['Enums']['participant_role']
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      votes: {
        Row: {
          category_id: string
          created_at: string
          id: string
          top_1_look_id: string
          top_2_look_id: string
          top_3_look_id: string
          updated_at: string
          voter_id: string
        }
        Insert: {
          category_id: string
          created_at?: string
          id?: string
          top_1_look_id: string
          top_2_look_id: string
          top_3_look_id: string
          updated_at?: string
          voter_id: string
        }
        Update: {
          category_id?: string
          created_at?: string
          id?: string
          top_1_look_id?: string
          top_2_look_id?: string
          top_3_look_id?: string
          updated_at?: string
          voter_id?: string
        }
        Relationships: [
          {
            foreignKeyName: 'votes_category_id_fkey'
            columns: ['category_id']
            isOneToOne: false
            referencedRelation: 'categories'
            referencedColumns: ['id']
          },
          {
            foreignKeyName: 'votes_voter_id_fkey'
            columns: ['voter_id']
            isOneToOne: false
            referencedRelation: 'participants'
            referencedColumns: ['id']
          },
          {
            foreignKeyName: 'votes_top_1_look_fkey'
            columns: ['top_1_look_id', 'category_id']
            isOneToOne: false
            referencedRelation: 'looks'
            referencedColumns: ['id', 'category_id']
          },
          {
            foreignKeyName: 'votes_top_2_look_fkey'
            columns: ['top_2_look_id', 'category_id']
            isOneToOne: false
            referencedRelation: 'looks'
            referencedColumns: ['id', 'category_id']
          },
          {
            foreignKeyName: 'votes_top_3_look_fkey'
            columns: ['top_3_look_id', 'category_id']
            isOneToOne: false
            referencedRelation: 'looks'
            referencedColumns: ['id', 'category_id']
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      category_has_status: {
        Args: {
          p_category_id: string
          p_statuses: Database['public']['Enums']['category_status'][]
        }
        Returns: boolean
      }
      is_jurado: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
    }
    Enums: {
      category_status: 'draft' | 'runway' | 'voting' | 'closed'
      participant_role: 'jurado' | 'concursante'
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type PublicSchema = Database['public']

/** Row type of a public table, e.g. `Tables<'looks'>` */
export type Tables<T extends keyof PublicSchema['Tables']> = PublicSchema['Tables'][T]['Row']

/** Insert payload of a public table */
export type TablesInsert<T extends keyof PublicSchema['Tables']> = PublicSchema['Tables'][T]['Insert']

/** Update payload of a public table */
export type TablesUpdate<T extends keyof PublicSchema['Tables']> = PublicSchema['Tables'][T]['Update']

/** Public enum type, e.g. `Enums<'category_status'>` */
export type Enums<T extends keyof PublicSchema['Enums']> = PublicSchema['Enums'][T]
