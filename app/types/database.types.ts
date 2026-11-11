
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "graphql_public": {
          Tables: {
            [_ in never]: never
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "graphql":
{ Args: { "extensions"?: Json,"operationName"?: string,"query"?: string,"variables"?: Json }; Returns: Json
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        },"public": {
          Tables: {
            "categories": {
                  Row: {
                    "created_at": string,"id": string,"intro_text": string | null,"kind": Database["public"]["Enums"]["category_kind"],"runway_id": string,"title": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"intro_text"?: string | null,"kind"?: Database["public"]["Enums"]["category_kind"],"runway_id": string,"title": string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"intro_text"?: string | null,"kind"?: Database["public"]["Enums"]["category_kind"],"runway_id"?: string,"title"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "categories_runway_id_fkey"
      columns: ["runway_id"]
isOneToOne: false
      referencedRelation: "runways"
      referencedColumns: ["id"]
    }
                  ]
                },"category_group_members": {
                  Row: {
                    "category_id": string,"created_at": string,"group_id": string,"id": string,"participant_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "category_id": string,"created_at"?: string,"group_id": string,"id"?: string,"participant_id": string
                  }
                  Update: {
                    "category_id"?: string,"created_at"?: string,"group_id"?: string,"id"?: string,"participant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "category_group_members_group_fkey"
      columns: ["group_id", "category_id"]
isOneToOne: false
      referencedRelation: "category_groups"
      referencedColumns: ["id", "category_id"]
    },
                    {
      foreignKeyName: "category_group_members_participant_id_fkey"
      columns: ["participant_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    }
                  ]
                },"category_group_photos": {
                  Row: {
                    "category_id": string,"created_at": string,"group_id": string,"image_url": string | null,"image2_url": string | null,"image3_url": string | null,"image4_url": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "category_id": string,"created_at"?: string,"group_id": string,"image_url"?: string | null,"image2_url"?: string | null,"image3_url"?: string | null,"image4_url"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "category_id"?: string,"created_at"?: string,"group_id"?: string,"image_url"?: string | null,"image2_url"?: string | null,"image3_url"?: string | null,"image4_url"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "category_group_photos_group_fkey"
      columns: ["group_id", "category_id"]
isOneToOne: true
      referencedRelation: "category_groups"
      referencedColumns: ["id", "category_id"]
    }
                  ]
                },"category_group_votes": {
                  Row: {
                    "category_id": string,"created_at": string,"group_id": string,"id": string,"updated_at": string,"voter_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "category_id": string,"created_at"?: string,"group_id": string,"id"?: string,"updated_at"?: string,"voter_id": string
                  }
                  Update: {
                    "category_id"?: string,"created_at"?: string,"group_id"?: string,"id"?: string,"updated_at"?: string,"voter_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "category_group_votes_group_fkey"
      columns: ["group_id", "category_id"]
isOneToOne: false
      referencedRelation: "category_groups"
      referencedColumns: ["id", "category_id"]
    },
                    {
      foreignKeyName: "category_group_votes_voter_id_fkey"
      columns: ["voter_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    }
                  ]
                },"category_groups": {
                  Row: {
                    "category_id": string,"created_at": string,"id": string,"name": string,"position": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "category_id": string,"created_at"?: string,"id"?: string,"name": string,"position": number,"updated_at"?: string
                  }
                  Update: {
                    "category_id"?: string,"created_at"?: string,"id"?: string,"name"?: string,"position"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "category_groups_category_id_fkey"
      columns: ["category_id"]
isOneToOne: false
      referencedRelation: "categories"
      referencedColumns: ["id"]
    }
                  ]
                },"category_queen_votes": {
                  Row: {
                    "category_id": string,"created_at": string,"id": string,"queen_id": string,"updated_at": string,"voter_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "category_id": string,"created_at"?: string,"id"?: string,"queen_id": string,"updated_at"?: string,"voter_id": string
                  }
                  Update: {
                    "category_id"?: string,"created_at"?: string,"id"?: string,"queen_id"?: string,"updated_at"?: string,"voter_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "category_queen_votes_category_id_fkey"
      columns: ["category_id"]
isOneToOne: false
      referencedRelation: "categories"
      referencedColumns: ["id"]
    },
                    {
      foreignKeyName: "category_queen_votes_queen_id_fkey"
      columns: ["queen_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    },
                    {
      foreignKeyName: "category_queen_votes_voter_id_fkey"
      columns: ["voter_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    }
                  ]
                },"jury_looks": {
                  Row: {
                    "category_id": string,"created_at": string,"id": string,"image_url": string,"image2_url": string | null,"image3_url": string | null,"image4_url": string | null,"intro": string,"participant_id": string,"updated_at": string,"uploaded_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "category_id": string,"created_at"?: string,"id"?: string,"image_url": string,"image2_url"?: string | null,"image3_url"?: string | null,"image4_url"?: string | null,"intro": string,"participant_id": string,"updated_at"?: string,"uploaded_by"?: string | null
                  }
                  Update: {
                    "category_id"?: string,"created_at"?: string,"id"?: string,"image_url"?: string,"image2_url"?: string | null,"image3_url"?: string | null,"image4_url"?: string | null,"intro"?: string,"participant_id"?: string,"updated_at"?: string,"uploaded_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "jury_looks_category_id_fkey"
      columns: ["category_id"]
isOneToOne: false
      referencedRelation: "categories"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "jury_looks_participant_id_fkey"
      columns: ["participant_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "jury_looks_uploaded_by_fkey"
      columns: ["uploaded_by"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    }
                  ]
                },"looks": {
                  Row: {
                    "category_id": string,"created_at": string,"id": string,"image_url": string,"image2_url": string | null,"image3_url": string | null,"image4_url": string | null,"intro": string | null,"participant_id": string,"updated_at": string,"uploaded_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "category_id": string,"created_at"?: string,"id"?: string,"image_url": string,"image2_url"?: string | null,"image3_url"?: string | null,"image4_url"?: string | null,"intro"?: string | null,"participant_id": string,"updated_at"?: string,"uploaded_by"?: string | null
                  }
                  Update: {
                    "category_id"?: string,"created_at"?: string,"id"?: string,"image_url"?: string,"image2_url"?: string | null,"image3_url"?: string | null,"image4_url"?: string | null,"intro"?: string | null,"participant_id"?: string,"updated_at"?: string,"uploaded_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "looks_category_id_fkey"
      columns: ["category_id"]
isOneToOne: false
      referencedRelation: "categories"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "looks_participant_id_fkey"
      columns: ["participant_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "looks_uploaded_by_fkey"
      columns: ["uploaded_by"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    }
                  ]
                },"participants": {
                  Row: {
                    "avatar_url": string | null,"created_at": string,"drag_name": string | null,"email": string,"id": string,"name": string,"role": Database["public"]['Enums']["participant_role"],"updated_at": string,"user_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "avatar_url"?: string | null,"created_at"?: string,"drag_name"?: string | null,"email": string,"id"?: string,"name": string,"role"?: Database["public"]['Enums']["participant_role"],"updated_at"?: string,"user_id"?: string | null
                  }
                  Update: {
                    "avatar_url"?: string | null,"created_at"?: string,"drag_name"?: string | null,"email"?: string,"id"?: string,"name"?: string,"role"?: Database["public"]['Enums']["participant_role"],"updated_at"?: string,"user_id"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"runway_guests": {
                  Row: {
                    "created_at": string,"id": string,"invited_by": string | null,"participant_id": string,"runway_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"invited_by"?: string | null,"participant_id": string,"runway_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"invited_by"?: string | null,"participant_id"?: string,"runway_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "runway_guests_invited_by_fkey"
      columns: ["invited_by"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "runway_guests_participant_id_fkey"
      columns: ["participant_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "runway_guests_runway_id_fkey"
      columns: ["runway_id"]
isOneToOne: false
      referencedRelation: "runways"
      referencedColumns: ["id"]
    }
                  ]
                },"runways": {
                  Row: {
                    "created_at": string,"id": string,"runway_date": string,"status": Database["public"]['Enums']["runway_status"],"updated_at": string,"week_number": number
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"runway_date"?: string,"status"?: Database["public"]['Enums']["runway_status"],"updated_at"?: string,"week_number": number
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"runway_date"?: string,"status"?: Database["public"]['Enums']["runway_status"],"updated_at"?: string,"week_number"?: number
                  }
                  Relationships: [
                    
                  ]
                },"votes": {
                  Row: {
                    "created_at": string,"id": string,"runway_id": string,"top_1_participant_id": string,"top_2_participant_id": string,"top_3_participant_id": string,"updated_at": string,"voter_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"runway_id": string,"top_1_participant_id": string,"top_2_participant_id": string,"top_3_participant_id": string,"updated_at"?: string,"voter_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"runway_id"?: string,"top_1_participant_id"?: string,"top_2_participant_id"?: string,"top_3_participant_id"?: string,"updated_at"?: string,"voter_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "votes_runway_id_fkey"
      columns: ["runway_id"]
isOneToOne: false
      referencedRelation: "runways"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "votes_top_1_participant_id_fkey"
      columns: ["top_1_participant_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "votes_top_2_participant_id_fkey"
      columns: ["top_2_participant_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "votes_top_3_participant_id_fkey"
      columns: ["top_3_participant_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "votes_voter_id_fkey"
      columns: ["voter_id"]
isOneToOne: false
      referencedRelation: "participants"
      referencedColumns: ["id"]
    }
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "can_access_category":
{ Args: { "p_category_id": string }; Returns: boolean
                           },
"can_access_runway":
{ Args: { "p_runway_id": string }; Returns: boolean
                           },
"are_rivals":
{ Args: { "p_a": string,"p_b": string,"p_category_id": string }; Returns: boolean
                           },
"are_teammates":
{ Args: { "p_a": string,"p_b": string,"p_category_id": string }; Returns: boolean
                           },
"category_group_result":
{ Args: { "p_category_id": string }; Returns: { group_id: string, total_votes: number, is_winner: boolean }[]
                           },
"category_queen_result":
{ Args: { "p_category_id": string }; Returns: { participant_id: string, total_votes: number }[]
                           },
"category_has_status":
{ Args: { "p_category_id": string,"p_statuses": (Database["public"]['Enums']["runway_status"])[] }; Returns: boolean
                           },
"current_participant_id":
{ Args: Record<PropertyKey, never>; Returns: string
                           },
"is_active_category_guest":
{ Args: { "p_category_id": string }; Returns: boolean
                           },
"is_active_runway_guest":
{ Args: { "p_runway_id": string }; Returns: boolean
                           },
"is_guest":
{ Args: Record<PropertyKey, never>; Returns: boolean
                           },
"is_jurado":
{ Args: Record<PropertyKey, never>; Returns: boolean
                           },
"is_runway_contestant":
{ Args: { "p_participant_id": string,"p_runway_id": string }; Returns: boolean
                           },
"participant_group_id":
{ Args: { "p_category_id": string,"p_participant_id": string }; Returns: string
                           },
"participant_is_guest":
{ Args: { "p_participant_id": string }; Returns: boolean
                           },
"runway_has_status":
{ Args: { "p_runway_id": string,"p_statuses": (Database["public"]['Enums']["runway_status"])[] }; Returns: boolean
                           },
"runway_ranking":
{ Args: { "p_runway_id": string }; Returns: {
              "participant_id": string,"place": number,"total_points": number
            }[]
                           },
"runway_top_three":
{ Args: { "p_runway_id": string }; Returns: {
              "participant_id": string,"place": number,"total_points": number
            }[]
                           }
          }
          Enums: {
            "category_kind": "individual"|"group","participant_role": "jurado"|"concursante"|"invitado","runway_status": "draft"|"werk_room"|"runway"|"voting"|"reveal"|"closed"
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "graphql_public": {
          Enums: {
            
          }
        },"public": {
          Enums: {
            "category_kind": ["individual", "group"],"participant_role": ["jurado", "concursante", "invitado"],"runway_status": ["draft", "werk_room", "runway", "voting", "reveal", "closed"]
          }
        }
} as const
